//
//  Fortify
//
//  Created by Mikhail Mirmikov on 02.09.2024
//
import SwiftUI
import UIKit
import MessageUI
import LocalAuthentication
import KeychainSwift
import Foundation

@main
struct PasswordGeneratorApp: App {
    @StateObject var authManager = AuthManager()
    @StateObject var folderManager = FolderManager()

    var body: some Scene {
        WindowGroup {
            if authManager.isLoggedIn {
                if authManager.isPasswordEntered {
                    ContentView()
                        .environmentObject(authManager)
                        .preferredColorScheme(.none) // Автоматическое переключение между светлой и темной темами
                        .environmentObject(folderManager)
                } else {
                    LockScreenView()
                        .environmentObject(authManager)
                        .preferredColorScheme(.none)
                        .environmentObject(folderManager)
                }
            } else {
                WelcomeView()
                    .environmentObject(authManager)
                    .environmentObject(folderManager)
                    .preferredColorScheme(.none)
            }
        }
    }
}

class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var isPasswordEntered: Bool = true
    @Published var seedPhrase: String = ""
    
    private let seedPhraseKey = "userSeedPhrase"
    private let passwordKey = "appPassword"
    private let keychain = KeychainSwift()

    init() {
        // Проверка наличия seed-фразы для входа
        if let savedSeed = UserDefaults.standard.string(forKey: seedPhraseKey) {
            self.seedPhrase = savedSeed
            self.isLoggedIn = true
        }
        
        if isPasswordSet() {
            self.isPasswordEntered = false
        } else {
            self.isPasswordEntered = true
        }
    }
    
    // Метод для входа и сохранения seed-фразы
    func login(with seed: String) {
        self.seedPhrase = seed
        self.isLoggedIn = true
        self.isPasswordEntered = !isPasswordSet() // Пропуск LockScreenView, если пароля нет
        UserDefaults.standard.set(seed, forKey: seedPhraseKey)
    }
    
    // Установка 6-значного пароля и сохранение его в Keychain
    func setPassword(_ password: [Int]) {
        guard password.count == 6 else { return }
        let passwordString = password.map { String($0) }.joined()
        keychain.set(passwordString, forKey: passwordKey)
        self.isPasswordEntered = true
    }

    // Проверка, установлен ли пароль
    func isPasswordSet() -> Bool {
        return keychain.get(passwordKey) != nil
    }

    // Верификация 6-значного пароля для разблокировки
    func verifyPassword(_ password: [Int]) -> Bool {
        guard password.count == 6 else { return false }
        
        let savedPasswordString = keychain.get(passwordKey) ?? ""
        let savedPassword = savedPasswordString.compactMap { Int(String($0)) }
        
        if savedPassword == password {
            self.isPasswordEntered = true
            return true
        } else {
            return false
        }
    }

    // Удаление пароля
    func removePassword() {
        keychain.delete(passwordKey)
        self.isPasswordEntered = true // Пропускаем LockScreenView, если пароля нет
    }

    // Выход из аккаунта и удаление seed-фразы и пароля
    func logout() {
        self.seedPhrase = ""
        self.isLoggedIn = false
        self.isPasswordEntered = true // Пропуск LockScreenView
        UserDefaults.standard.removeObject(forKey: seedPhraseKey)
        keychain.delete(passwordKey)
    }
    
    // Аутентификация с использованием Face ID / Touch ID
    func authenticateWithBiometrics(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Для доступа к приложению") { success, _ in
                DispatchQueue.main.async {
                    self.isPasswordEntered = success
                    completion(success)
                }
            }
        } else {
            completion(false)
        }
    }
    
    func exportPasswords(completion: @escaping (String?) -> Void) {
            guard let url = URL(string: "http://localhost:8000/export_passwords?seed=\(self.seedPhrase)") else {
                completion(nil)
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: String], let passwords = json["passwords"] {
                    completion(passwords)
                } else {
                    completion(nil)
                }
            }.resume()
        }
    }


struct MailView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentation
    @Binding var result: Result<MFMailComposeResult, Error>?

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var presentation: PresentationMode
        @Binding var result: Result<MFMailComposeResult, Error>?

        init(presentation: Binding<PresentationMode>, result: Binding<Result<MFMailComposeResult, Error>?>) {
            _presentation = presentation
            _result = result
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            defer {
                $presentation.wrappedValue.dismiss()
            }
            guard error == nil else {
                self.result = .failure(error!)
                return
            }
            self.result = .success(result)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(presentation: presentation, result: $result)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients(["fortify@icloud.com"]) // Указываем адрес получателя
        vc.setSubject("Обращение в поддержку Fortify") // Тема письма
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}

// MARK: - Экран Вход и Регистрация
struct WelcomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showSeedPhrase = false
    @State private var seedPhrase: String = ""
    @State private var showLoginView = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Название приложения
            Text("Fortify")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundColor(.blue)
            
            // Короткая фраза о том, что Fortify — безопасное хранилище паролей
            Text("Создавайте и надёжно, безопасно храните свои пароли")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            // Кнопка-плитка "Создать новое хранилище"
            Button(action: {
                registerUser()
            }) {
                HStack(spacing: 16) {
                    // Иконка "плюс" (пример)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Создать новое хранилище")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                        
                        Text("Сгенерировать Seed-фразу")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            
            // Кнопка-плитка "Подключить существующее хранилище"
            Button(action: {
                showLoginView = true
            }) {
                HStack(spacing: 16) {
                    // Иконка "стрелка вниз" (пример)
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Подключить хранилище")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                        
                        Text("Импорт, восстановление или просмотр")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            
            Spacer()
        }
        .padding(.bottom, 40)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.white, Color.blue.opacity(0.05)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .edgesIgnoringSafeArea(.all)
        // Модальное окно с Seed-фразой
        .sheet(isPresented: $showSeedPhrase) {
            SeedPhraseView(seedPhrase: $seedPhrase)
        }
        // Модальное окно для входа
        .sheet(isPresented: $showLoginView) {
            LoginView()
        }
    }
    
    /// Метод регистрации (пример)
    func registerUser() {
        guard let url = URL(string: "http://localhost:8000/register") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else { return }
            let response = try? JSONDecoder().decode([String: String].self, from: data)
            
            if let response = response, let seed = response["seed"] {
                DispatchQueue.main.async {
                    self.seedPhrase = seed
                    self.showSeedPhrase = true
                }
            }
        }.resume()
    }
}


struct SeedPhraseView: View {
    @Binding var seedPhrase: String
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @State private var isSeedVisible: Bool = false
    @State private var isCopied: Bool = false

    var body: some View {
        VStack(spacing: 30) {
            // Заголовок
            Text("Ваша сид-фраза")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 20)
                .foregroundColor(.blue)
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Сид-фраза по словам с нумерацией
            VStack(spacing: 15) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                    spacing: 15
                ) {
                    ForEach(seedPhrase.split(separator: " ").enumerated().map { $0 }, id: \.offset) { index, word in
                        VStack(spacing: 5) {
                            // Номер слова
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            // Слово в блоке
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 100, height: 50) // Фиксированный размер блока
                                    .cornerRadius(8)
                                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                                
                                if isSeedVisible {
                                    Text(word)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.primary)
                                } else {
                                    Text("****")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)

                // Кнопка "Глазик" для показа/скрытия
                HStack {
                    Button(action: {
                        withAnimation {
                            isSeedVisible.toggle()
                        }
                    }) {
                        Image(systemName: isSeedVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                            .scaleEffect(isSeedVisible ? 1.2 : 1.0)
                    }
                    
                    Spacer()
                    
                    // Кнопка "Копировать"
                    Button(action: {
                        UIPasteboard.general.string = seedPhrase
                        withAnimation {
                            isCopied = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                isCopied = false
                            }
                        }
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                            .scaleEffect(isCopied ? 1.2 : 1.0)
                    }
                }
            }

            // Анимация "Сохраните свою сид-фразу"
            Spacer()
            SaveSeedPhraseAnimationView() // Анимация

            // Кнопка "Продолжить"
            Button(action: {
                authManager.login(with: seedPhrase)
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Продолжить")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(12)
                    .shadow(color: .green.opacity(0.5), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 20)
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }
}

// Анимация "Сохраните свою сид-фразу"
struct SaveSeedPhraseAnimationView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "lock.fill")
                    .resizable()
                    .frame(width: 40, height: 50)
                    .foregroundColor(.blue)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
                
                Text("Сохраните вашу seed-фразу в безопасном месте!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.leading, 10)
            }
            .padding()
            .background(Color.blue.opacity(0.8))
            .cornerRadius(15)
            .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 5)
            .onAppear {
                isAnimating = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
}

struct LoginView: View {
    @State private var seedPhrase: [String] = Array(repeating: "", count: 12) // Массив для ввода сид-фразы
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @State private var isSeedVisible: Bool = false
    @State private var loginError: Bool = false
    @State private var showLoading: Bool = false

    var body: some View {
        VStack(spacing: 30) {
            // Заголовок
            Text("Введите сид-фразу")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 20)
                .foregroundColor(.blue)
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)

            // Сид-фраза по словам с вводом
            VStack(spacing: 15) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                    spacing: 15
                ) {
                    ForEach(0..<seedPhrase.count, id: \.self) { index in
                        VStack(spacing: 5) {
                            // Номер слова
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.gray)

                            // Поле для ввода слова
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 100, height: 50)
                                    .cornerRadius(8)
                                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)

                                if isSeedVisible {
                                    TextField("", text: $seedPhrase[index])
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                } else {
                                    SecureField("", text: $seedPhrase[index])
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)

                // Кнопки управления
                HStack {
                    // Кнопка "Глазик"
                    Button(action: {
                        withAnimation {
                            isSeedVisible.toggle()
                        }
                    }) {
                        Image(systemName: isSeedVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                    }

                    Spacer()

                    // Кнопка "Вставить" для вставки из буфера обмена
                    Button(action: {
                        if let clipboardText = UIPasteboard.general.string {
                            let words = clipboardText.split(separator: " ").map(String.init)
                            if words.count == seedPhrase.count {
                                seedPhrase = words
                            }
                        }
                    }) {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()

            if showLoading {
                ProgressView()
                    .padding()
            } else {
                Button(action: {
                    loginUser()
                }) {
                    Text("Войти")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(12)
                        .shadow(color: .green.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }

            // Ошибка при неверной сид-фразе
            if loginError {
                Text("Неверная сид-фраза. Попробуйте снова.")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 10)
                    .transition(.opacity)
            }
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }
    


    func loginUser() {
            guard let url = URL(string: "http://localhost:8000/login") else {
                print("Некорректный URL")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Формируем тело запроса
            let body: [String: String] = ["seed": seedPhrase.joined(separator: " ")]

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
                request.httpBody = jsonData
            } catch {
                print("Ошибка сериализации JSON: \(error)")
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Ошибка запроса: \(error)")
                    return
                }

                guard let data = data else {
                    print("Нет данных")
                    return
                }

                do {
                    // Лог для отладки ответа
                    print("Response: \(String(data: data, encoding: .utf8) ?? "Нет данных")")

                    // Декодируем ответ от сервера
                    if let responseJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
                       let message = responseJSON["message"] {
                        print("Сообщение от сервера: \(message)")
                        // Успешный вход
                        DispatchQueue.main.async {
                            authManager.login(with: seedPhrase.joined(separator: " "))
                            presentationMode.wrappedValue.dismiss()
                        }
                    } else {
                        DispatchQueue.main.async {
                            loginError = true
                        }
                    }
                } catch {
                    print("Ошибка декодирования ответа: \(error)")
                }
            }.resume()
        }
    }

// Вспомогательная структура для создания анимаций иконок
struct AnimatedIconView: View {
    var icon: String
    var text: String
    var index: Int
    @Binding var currentIconIndex: Int

    var body: some View {
        VStack {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: UIScreen.main.bounds.width * 0.2, height: UIScreen.main.bounds.width * 0.3) // Очень большие иконки
                .foregroundColor(.blue)
                .opacity(currentIconIndex == index ? 1 : 0)
                .scaleEffect(currentIconIndex == index ? 1 : 0.8)
                .rotationEffect(.degrees(currentIconIndex == index ? 0 : -10))

            Text(text)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .opacity(currentIconIndex == index ? 1 : 0)
                .scaleEffect(currentIconIndex == index ? 1 : 0.8)
        }
        .animation(Animation.spring(response: 0.8, dampingFraction: 0.5), value: currentIconIndex)
    }
}


struct ErrorResponse: Codable {
    let detail: [ErrorDetail]
}

struct ErrorDetail: Codable {
    let loc: [String]
    let msg: String
    let type: String
}

// MARK: - Главный экран приложения
struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PasswordGeneratorView()
                .tabItem {
                    Label("Генератор", systemImage: "key.fill")
                }
                .tag(0)
            SavedPasswordsView()
                .tabItem {
                    Label("Сохраненные", systemImage: "folder.fill")
                }
                .tag(1)
            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
    }
}

// MARK: - Генератор паролей
struct AdBannerView: View {
    /// Ссылка для перехода при клике на баннер
    let linkURL: String
    /// Ссылка на изображение (URL-адрес)
    let bannerImageURL: String

    var body: some View {
        // Кнопка, при нажатии открывает ссылку
        Button(action: {
            if let url = URL(string: linkURL) {
                UIApplication.shared.open(url)
            }
        }) {
            // Содержимое баннера
            VStack {
                // Загружаем картинку из интернета
                AsyncImage(url: URL(string: bannerImageURL)) { phase in
                    switch phase {
                    case .empty:
                        // Плейсхолдер во время загрузки
                        ProgressView()
                            .frame(height: 80)
                    case .success(let image):
                        // Успешно загруженное изображение
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80)
                            .cornerRadius(12)
                            .padding(.horizontal, 10)
                    case .failure(_):
                        // Если изображение не загрузилось
                        Image(systemName: "exclamationmark.triangle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80)
                            .foregroundColor(.red)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(24)
            .shadow(
                color: Color.black.opacity(0.1),
                radius: 5, x: 0, y: 2
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        // Убираем эффект системной кнопки
        .buttonStyle(PlainButtonStyle())
    }
}
// MARK: - Основной экран Генератора паролей
struct PasswordGeneratorView: View {
    @State private var numberOfPasswords = "1"
    @State private var passwordLength = "16"
    @State private var useUppercase = true
    @State private var useNumbers = true
    @State private var useSpecialCharacters = true
    @State private var generatedPasswords: [String] = []
    @State private var showCopiedAlert = false
    @State private var selectedPassword = ""
    @State private var showSavePasswordView = false
    @State private var passwordStrengthPercentage: Double = 100
    // ADS BANNERS
    @State private var showBanner = false
    
    @EnvironmentObject var authManager: AuthManager
    

    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    // Заголовок
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .foregroundColor(.blue)
                        Text("Генератор паролей")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.bottom, 5)
                    
                    // Блок настроек для генерации паролей
                    VStack {
                        HStack {
                            VStack {
                                TextField("Количество паролей", text: $numberOfPasswords)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                
                                TextField("Длина пароля", text: $passwordLength)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                    .onChange(of: passwordLength, perform: { _ in
                                        updatePasswordStrength()
                                    })
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Круговая диаграмма для отображения силы пароля
                            CircleChartView(percentage: $passwordStrengthPercentage)
                                .frame(width: 100, height: 100)
                                .padding(.leading, 10)
                        }
                        Spacer().frame(height: 20)
                        
                        // Кнопки для настроек
                        HStack(spacing: 30) {
                            circularButton(
                                icon: "arrow.up",
                                text: "Заглавные",
                                isActive: useUppercase,
                                action: {
                                    useUppercase.toggle()
                                    updatePasswordStrength()
                                }
                            )
                            
                            circularButton(
                                icon: "123.rectangle",
                                text: "Цифры",
                                isActive: useNumbers,
                                action: {
                                    useNumbers.toggle()
                                    updatePasswordStrength()
                                }
                            )
                            
                            circularButton(
                                icon: "asterisk.circle",
                                text: "Символы",
                                isActive: useSpecialCharacters,
                                action: {
                                    useSpecialCharacters.toggle()
                                    updatePasswordStrength()
                                }
                            )
                        }
                        
                        // Кнопка для генерации паролей
                        Button(action: {
                            generatePasswords()
                        }) {
                            Text("Сгенерировать")
                                .fontWeight(.bold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                                .shadow(radius: 5)
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.1),
                            radius: 5, x: 0, y: 2)
                    .padding([.leading, .trailing], 20)
                    
                    // Отображаем баннер, если showBanner == true
                    if showBanner {
                        AdBannerView(
                            linkURL: "https://apple.com",
                            bannerImageURL: "https://via.placeholder.com/400x100.png"
                                    )
                    }
                    
                    // Секция с паролями
                    ScrollView {
                        VStack(spacing: 15) {
                            ForEach(generatedPasswords, id: \.self) { password in
                                VStack {
                                    HStack {
                                        Text(password)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        // Кнопка для копирования пароля
                                        Button(action: {
                                            copyToClipboard(text: password)
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        // Кнопка для сохранения пароля
                                        Button(action: {
                                            selectedPassword = password
                                            showSavePasswordView = true
                                        }) {
                                            Image(systemName: "square.and.arrow.down")
                                                .foregroundColor(.green)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding()
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(24)
                                .shadow(color: Color.black.opacity(0.1),
                                        radius: 5, x: 0, y: 2)
                                .padding([.leading, .trailing], 20)
                            }
                        }
                        .padding(.bottom, 80)
                    }
                }
            }
        }
        // Вью для сохранения пароля
        .sheet(isPresented: $showSavePasswordView) {
            SavePasswordView(
                isPresented: $showSavePasswordView,
                currentPassword: $selectedPassword,
                saveAction: savePassword
            )
            .environmentObject(authManager)
        }
    }
    
    // MARK: - Кнопка настройки (круглая)
    private func circularButton(icon: String, text: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.blue : Color(UIColor.secondarySystemBackground))
                        .frame(width: 60, height: 60)
                        .shadow(color: isActive ? Color.blue.opacity(0.4) : Color.black.opacity(0.1),
                                radius: 5, x: 0, y: 3)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(isActive ? .white : .gray)
                }
                
                Text(text)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Сохранение пароля на сервер
    func savePassword(service: String, email: String, username: String, password: String) {
        guard let url = URL(string: "http://localhost:8000/save_password") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let passwordData = PasswordData(
            password_name: "NewPassword",
            password_value: password,
            service: service,
            email: email,
            username: username
        )
        
        let body: [String: Any] = [
            "seed": authManager.seedPhrase,
            "password_data": passwordData.toDictionary()
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
            request.httpBody = jsonData
        } catch {
            print("Ошибка сериализации JSON: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { _, _, _ in
            // Обработка результата сохранения
        }.resume()
    }
    
    // MARK: - Генерация пароля(ей)
    private func generatePasswords() {
        guard
            let num = Int(numberOfPasswords),
            let length = Int(passwordLength)
        else { return }
        
        generatedPasswords = (0..<num).map { _ in
            generatePassword(length: length)
        }
        updatePasswordStrength()
    }
    
    private func generatePassword(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz"
        let upperLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let numbers = "0123456789"
        let specialCharacters = "!@#$%^&*()_-+=<>?"
        
        var characters = letters
        if useUppercase { characters += upperLetters }
        if useNumbers { characters += numbers }
        if useSpecialCharacters { characters += specialCharacters }
        
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    // MARK: - Обновление индикатора силы пароля
    private func updatePasswordStrength() {
        guard let length = Int(passwordLength) else {
            passwordStrengthPercentage = 0
            return
        }
        
        if length < 8 {
            withAnimation(.spring()) {
                passwordStrengthPercentage = 0
            }
            return
        }
        
        var strength = 0.0
        
        // Длина пароля
        if length >= 12 {
            strength += 25
        } else if length >= 8 {
            strength += 15
        }
        
        // Остальные параметры безопасности
        if useUppercase { strength += 25 }
        if useNumbers { strength += 25 }
        if useSpecialCharacters { strength += 25 }
        
        withAnimation(.spring()) {
            passwordStrengthPercentage = min(strength, 100)
        }
    }
    
    // MARK: - Копирование пароля в буфер обмена
    private func copyToClipboard(text: String) {
        UIPasteboard.general.string = text
        showCopiedAlert = true
    }
}

// MARK: - Круговая диаграмма силы пароля
struct CircleChartView: View {
    @Binding var percentage: Double
    
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: CGFloat(percentage / 100))
                .stroke(
                    percentage < 40 ? Color.red :
                        (percentage < 80 ? Color.yellow : Color.green),
                    style: StrokeStyle(lineWidth: 24, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(percentage))%")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.blue)
        }
    }
}

// MARK: - SavePasswordView
struct SavePasswordView: View {
    @Binding var isPresented: Bool
    @Binding var currentPassword: String
    @EnvironmentObject var authManager: AuthManager
    var saveAction: (String, String, String, String) -> Void
    
    @State private var service = ""
    @State private var email = ""
    @State private var username = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Секция с тенями для ввода данных
                VStack {
                    Section() {
                        CustomTextField(placeholder: "Сервис", text: $service)
                        CustomTextField(placeholder: "Email", text: $email)
                        CustomTextField(placeholder: "Username", text: $username)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground)) // Системный фон для адаптации к теме
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding([.leading, .trailing], 20) // Отступы от краев экрана
                
                // Секция с отображением текущего пароля
                VStack {
                    Section() {
                        HStack {
                            Text(currentPassword)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.gray)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                            Spacer()
                            Button(action: {
                                UIPasteboard.general.string = currentPassword
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground)) // Системный фон для адаптации к теме
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding([.leading, .trailing], 20) // Отступы от краев экрана
                
                Spacer()
                
                // Кнопка "Сохранить"
                Button(action: {
                    saveAction(service, email, username, currentPassword)
                    isPresented = false
                }) {
                    Text("Сохранить")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .padding([.leading, .trailing], 20)
                }
                .padding(.bottom, 20)
            }
            .navigationBarTitle("Сохранить пароль", displayMode: .inline)
            .navigationBarItems(leading: Button("Отмена") {
                isPresented = false
            })
        }
    }
    
    
    // Кастомный TextField для улучшения внешнего вида текстовых полей
    struct CustomTextField: View {
        var placeholder: String
        @Binding var text: String
        
        var body: some View {
            TextField(placeholder, text: $text)
                .padding()
                .background(Color(UIColor.secondarySystemBackground)) // Системный цвет для текстового поля
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                .padding(.bottom, 10)
        }
    }
}

// Кастомный TextField для улучшения внешнего вида текстовых полей
struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
            .padding(.bottom, 10)
    }
}

// MARK: - Отображение сохранённых паролей
struct SavedPasswordsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var folderManager: FolderManager
    
    @State private var savedPasswords: [PasswordData] = []
    @State private var showAddPasswordView = false
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    
    /// Выбранная папка (nil = «Все»)
    @State private var selectedFolderID: UUID? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    // Заголовок
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                        Text("Сохраненные пароли")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 5)
                    
                    // Поле поиска
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            
                            TextField("Поиск по сервису...", text: $searchText)
                                .onTapGesture {
                                    withAnimation {
                                        isSearching = true
                                    }
                                }
                                .textFieldStyle(PlainTextFieldStyle())
                                .frame(height: 40)
                        }
                        .padding(.horizontal)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        if isSearching {
                            Button(action: {
                                withAnimation {
                                    searchText = ""
                                    isSearching = false
                                    hideKeyboard()
                                }
                            }) {
                                Text("Отмена")
                                    .foregroundColor(.blue)
                                    .padding(.trailing, 10)
                                    .transition(.move(edge: .trailing))
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    // Если есть папки, показываем горизонтальный список
                    if !folderManager.folders.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                // Кнопка "Все"
                                Button(action: {
                                    withAnimation {
                                        selectedFolderID = nil
                                    }
                                }) {
                                    Text("Все")
                                        .fontWeight(selectedFolderID == nil ? .bold : .regular)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .foregroundColor(
                                            selectedFolderID == nil
                                            ? .white
                                            : .blue
                                        )
                                        .background(
                                            selectedFolderID == nil
                                            ? Color.blue // Цвет кнопки "Все" при выборе
                                            : Color.gray.opacity(0.2)
                                        )
                                        .cornerRadius(12)
                                }
                                
                                ForEach(folderManager.folders) { folder in
                                    // Каждая папка полностью закрашивается цветом folder.colorHex,
                                    // если она выбрана, иначе полупрозрачный фон
                                    Button(action: {
                                        withAnimation {
                                            selectedFolderID = folder.id
                                        }
                                    }) {
                                        Text(folder.name)
                                            .fontWeight(
                                                selectedFolderID == folder.id
                                                ? .bold
                                                : .regular
                                            )
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .foregroundColor(
                                                selectedFolderID == folder.id
                                                ? .white // на выбранной делаем белый текст
                                                : .blue  // на невыбранной — синий текст
                                            )
                                            .background(
                                                selectedFolderID == folder.id
                                                ? (Color(hex: folder.colorHex) ?? .gray)
                                                : Color.gray.opacity(0.2)
                                            )
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 8)
                    }
                    
                    if savedPasswords.isEmpty {
                        VStack {
                            Spacer()
                            Image(systemName: "tray")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                            Text("Нет сохраненных паролей")
                                .foregroundColor(.gray)
                                .padding()
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 15) {
                                ForEach(filteredPasswords, id: \.password_name) { password in
                                    PasswordCardView(password: password, savedPasswords: $savedPasswords)
                                        .padding(.horizontal)
                                        .transition(.opacity)
                                        .animation(.easeInOut(duration: 0.4), value: filteredPasswords)
                                }
                            }
                        }
                        .padding(.top, 3)
                    }
                }
                
                // Кнопка добавления
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showAddPasswordView = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 34))
                                .foregroundColor(.green)
                                .padding()
                        }
                        .sheet(isPresented: $showAddPasswordView) {
                            AddPasswordView(isPresented: $showAddPasswordView, savePassword: savePassword)
                        }
                    }
                    .padding([.trailing, .bottom], 10)
                }
            }
            .onAppear(perform: loadPasswords)
        }
    }
    
    /// Фильтруем пароли по поиску и по выбранной папке
    var filteredPasswords: [PasswordData] {
        let resultBySearch: [PasswordData]
        if searchText.isEmpty {
            resultBySearch = savedPasswords
        } else {
            resultBySearch = savedPasswords.filter {
                $0.service.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        guard let folderID = selectedFolderID else {
            // Если не выбрана конкретная папка
            return resultBySearch
        }
        
        // Фильтруем только те пароли, что состоят в этой папке
        return resultBySearch.filter { password in
            folderManager.password(password.password_name, isInFolder: folderID)
        }
    }
    
    // Сохранение нового пароля (пример)
    func savePassword(service: String, email: String, username: String, password: String) {
        guard let url = URL(string: "http://localhost:8000/save_password") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let passwordData = PasswordData(
            password_name: "UserDefinedPassword",
            password_value: password,
            service: service,
            email: email,
            username: username
        )
        
        let body: [String: Any] = [
            "seed": authManager.seedPhrase,
            "password_data": passwordData.toDictionary()
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
            request.httpBody = jsonData
        } catch {
            print("Ошибка сериализации JSON: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Ошибка запроса: \(error)")
                return
            }
            DispatchQueue.main.async {
                loadPasswords()
            }
        }.resume()
    }
    
    // Загрузка паролей
    func loadPasswords() {
        guard let url = URL(string: "http://localhost:8000/get_passwords?seed=\(authManager.seedPhrase)") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Ошибка загрузки паролей: \(error)")
                return
            }
            guard let data = data else {
                print("Нет данных")
                return
            }
            do {
                let decodedResponse = try JSONDecoder().decode(PasswordsResponse.self, from: data)
                DispatchQueue.main.async {
                    self.savedPasswords = decodedResponse.passwords
                }
            } catch {
                print("Ошибка декодирования данных: \(error)")
            }
        }.resume()
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}


struct AddPasswordView: View {
    @Binding var isPresented: Bool
    var savePassword: (String, String, String, String) -> Void
    
    @State private var service = ""
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isPasswordVisible = true // Изначально пароль видим
    
    var body: some View {
        NavigationView {
            VStack {
                // Секция с тенями для ввода информации о сервисе
                VStack {
                    Section() {
                        CustomTextField(placeholder: "Сервис", text: $service)
                        CustomTextField(placeholder: "Email", text: $email)
                        CustomTextField(placeholder: "Имя пользователя", text: $username)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground)) // Используем системный цвет для адаптации к теме
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding([.leading, .trailing], 20) // Отступы от краев экрана
                
                // Секция с тенями для пароля
                VStack {
                    Section() {
                        HStack {
                            if isPasswordVisible {
                                TextField("Пароль", text: $password) // Открытый ввод пароля
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(8)
                            } else {
                                SecureField("Пароль", text: $password) // Скрытый ввод пароля
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(8)
                            }
                            
                            // Кнопка для отображения/скрытия пароля
                            Button(action: {
                                isPasswordVisible.toggle() // Переключаем состояние видимости пароля
                            }) {
                                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.blue)
                            }
                            .padding(.trailing, 5) // Отступ справа для кнопки
                            .padding(.trailing, 0)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground)) // Используем системный цвет для адаптации к теме
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding([.leading, .trailing], 20) // Отступы от краев экрана
                
                Spacer()
                
                // Кнопка "Сохранить"
                Button(action: {
                    savePassword(service, email, username, password)
                    isPresented = false
                }) {
                    Text("Сохранить пароль")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .padding([.leading, .trailing], 20)
                }
                .padding(.bottom, 20)
            }
            .navigationBarTitle("Добавить пароль", displayMode: .inline)
            .navigationBarItems(leading: Button("Отмена") {
                isPresented = false
            })
        }
    }
    
    // Кастомный TextField для улучшения внешнего вида текстовых полей
    struct CustomTextField: View {
        var placeholder: String
        @Binding var text: String
        
        var body: some View {
            TextField(placeholder, text: $text)
                .padding()
                .background(Color(UIColor.secondarySystemBackground)) // Системный цвет для текстового поля
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                .padding(.bottom, 10)
        }
    }
}

// MARK: - PasswordCardView с контекстным меню
struct PasswordCardView: View {
    let password: PasswordData
    @Binding var savedPasswords: [PasswordData]
    @State private var isPasswordVisible: Bool = false
    @State private var isCopied: Bool = false
    @State private var showEditPasswordView = false
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var folderManager: FolderManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(password.service)
                    .font(.headline)
                    .foregroundColor(Color(.label))
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isPasswordVisible.toggle()
                    }
                }) {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundColor(.blue)
                }
                Button(action: {
                    UIPasteboard.general.string = password.password_value
                    withAnimation {
                        isCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isCopied = false
                        }
                    }
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                }
                Button(action: {
                    showEditPasswordView = true
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.orange)
                }
                Button(action: {
                    deletePassword()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            if isPasswordVisible {
                Text("Login: \(password.email)")
                    .font(.subheadline)
                    .foregroundColor(Color(.secondaryLabel))
                
                Text(password.password_value)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Color(.label))
            } else {
                Text("Пароль скрыт")
                    .font(.subheadline)
                    .foregroundColor(Color(.secondaryLabel))
            }
            
            if isCopied {
                Text("Скопировано!")
                    .font(.caption)
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showEditPasswordView) {
            EditPasswordView(
                isPresented: $showEditPasswordView,
                password: password,
                updatePassword: { name, service, email, username, newValue in
                    updatePassword(passwordName: name, service: service,
                                   email: email, username: username,
                                   newPasswordValue: newValue)
                }
            )
        }
        .contextMenu {
            // Список папок: добавить/убрать
            ForEach(folderManager.folders) { folder in
                Button(action: {
                    folderManager.togglePassword(password.password_name, folderID: folder.id)
                }) {
                    let isInFolder = folderManager.password(password.password_name, isInFolder: folder.id)
                    Label(
                        isInFolder
                        ? "Убрать из «\(folder.name)»"
                        : "Добавить в «\(folder.name)»",
                        systemImage: isInFolder ? "minus.circle" : "plus.circle"
                    )
                }
            }
        }
    }
    
    func updatePassword(passwordName: String, service: String, email: String,
                        username: String, newPasswordValue: String) {
        guard let url = URL(string: "http://localhost:8000/update_password") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "seed": authManager.seedPhrase,
            "password_data": [
                "password_name": passwordName,
                "new_password_value": newPasswordValue,
                "service": service,
                "email": email,
                "username": username
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
            request.httpBody = jsonData
        } catch {
            print("Ошибка сериализации JSON: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Ошибка при обновлении пароля: \(error)")
                return
            }
            DispatchQueue.main.async {
                loadPasswords()
            }
        }.resume()
    }
    
    func loadPasswords() {
        guard let url = URL(string: "http://localhost:8000/get_passwords?seed=\(authManager.seedPhrase)") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Ошибка загрузки паролей: \(error)")
                return
            }
            guard let data = data else {
                print("Нет данных")
                return
            }
            do {
                let decodedResponse = try JSONDecoder().decode(PasswordsResponse.self, from: data)
                DispatchQueue.main.async {
                    self.savedPasswords = decodedResponse.passwords
                }
            } catch {
                print("Ошибка декодирования данных: \(error)")
            }
        }.resume()
    }
    
    func deletePassword() {
        guard let url = URL(string: "http://localhost:8000/delete_password") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "seed": authManager.seedPhrase,
            "password_name": password.password_name
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
            request.httpBody = jsonData
        } catch {
            print("Ошибка сериализации JSON: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Ошибка при удалении пароля: \(error)")
                return
            }
            guard let data = data else {
                print("Нет данных от сервера")
                return
            }
            do {
                let responseJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let message = responseJSON?["message"] as? String {
                    print("Сообщение от сервера: \(message)")
                    DispatchQueue.main.async {
                        withAnimation {
                            savedPasswords.removeAll { $0.password_name == password.password_name }
                        }
                    }
                }
            } catch {
                print("Ошибка декодирования ответа: \(error)")
            }
        }.resume()
    }
}

struct PasswordsResponse: Codable {
    let passwords: [PasswordData]
}

struct PasswordData: Codable, Equatable {
    let password_name: String
    let password_value: String
    let service: String
    let email: String
    let username: String

    func toDictionary() -> [String: Any] {
        return [
            "password_name": password_name,
            "password_value": password_value,
            "service": service,
            "email": email,
            "username": username
        ]
    }
}


// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var folderManager: FolderManager
    
    @State private var isSeedPhraseVisible: Bool = false
    @State private var showingMailView = false
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil
    @State private var isCopied: Bool = false
    @State private var showingSetPasswordView = false
    @State private var showingSecurityView = false
    @State private var isPasswordEnabled = false
    @State private var isBiometricsEnabled = false
    @State private var hasCheckedPasswordOnce = false
    @State private var showAlertView = false
    @State private var isBannerVisible = false
    /// Новое состояние для показа экрана управления папками
    @State private var showingManageFoldersView = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.blue)
                        Text("Настройки")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 5)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            if isBannerVisible {
                                BannerView(isVisible: $isBannerVisible)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                    .animation(.easeInOut)
                            }
                            
                            // Кнопка "Безопасность"
                            Button(action: {
                                showingSecurityView = true
                            }) {
                                HStack {
                                    Image(systemName: "lock.shield")
                                        .foregroundColor(.blue)
                                    Text("Безопасность")
                                        .fontWeight(.bold)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                            }
                            .sheet(isPresented: $showingSecurityView) {
                                SecuritySettingsView()
                                    .environmentObject(authManager)
                            }
                            
                            // Кнопка "Экспортировать пароли"
                            Button(action: exportPasswords) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                        .foregroundColor(.blue)
                                    Text("Экспортировать пароли")
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                            }
                            
                            // Новая кнопка «Управление папками»
                            Button(action: {
                                showingManageFoldersView = true
                            }) {
                                HStack {
                                    Image(systemName: "folder.badge.plus")
                                        .foregroundColor(.blue)
                                    Text("Управление папками")
                                        .fontWeight(.bold)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                            }
                            .sheet(isPresented: $showingManageFoldersView) {
                                ManageFoldersView()
                                    .environmentObject(folderManager)
                            }
                            
                            // Кнопка "Contact"
                            Section {
                                Button(action: {
                                    self.showingMailView.toggle()
                                }) {
                                    HStack {
                                        Spacer()
                                        Text("Contact")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        Spacer()
                                    }
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 5)
                            }
                        }
                        .padding()
                    }
                    .onAppear {
                        if !hasCheckedPasswordOnce {
                            isPasswordEnabled = authManager.isPasswordSet()
                            hasCheckedPasswordOnce = true
                        }
                    }
                    
                    // Кнопка "Выйти из аккаунта"
                    Button(action: {
                        showAlertView = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Выйти из аккаунта")
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.red.opacity(0.2), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
                .sheet(isPresented: $showingMailView) {
                    MailView(result: self.$mailResult)
                }
                
                if showAlertView {
                    SaveSeedAlertView(isVisible: $showAlertView, onConfirm: {
                        authManager.logout()
                    })
                }
            }
        }
    }
    
    private func exportPasswords() {
        authManager.exportPasswords { passwords in
            guard let passwords = passwords else { return }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let dateString = dateFormatter.string(from: Date())
            let fileName = "FortifyPasswords_\(dateString).txt"
            
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            do {
                try passwords.write(to: fileURL, atomically: true, encoding: .utf8)
                
                DispatchQueue.main.async {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        let activityVC = UIActivityViewController(activityItems: [fileURL],
                                                                  applicationActivities: nil)
                        activityVC.completionWithItemsHandler = { _, completed, _, _ in
                            if completed {
                                print("Экспорт завершен успешно")
                            }
                        }
                        rootVC.present(activityVC, animated: true, completion: nil)
                    }
                }
            } catch {
                print("Ошибка при записи файла: \(error)")
            }
        }
    }
}


struct BannerView: View {
    @Binding var isVisible: Bool

    var body: some View {
        VStack {
            HStack {
                Text("Ознакомьтесь с проектом Fortify!")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    withAnimation {
                        isVisible = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
            .padding([.leading, .trailing, .top], 10)
            .onTapGesture {
                if let url = URL(string: "https://mirmikov.tech/fortify") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}


// Всплывающее окно с предупреждением
struct SaveSeedAlertView: View {
    @Binding var isVisible: Bool
    var onConfirm: () -> Void // Действие при подтверждении

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)

            Text("Сохраните вашу сид-фразу в безопасном месте. Без неё вы не сможете восстановить доступ к вашему аккаунту.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            HStack {
                Button(action: {
                    withAnimation {
                        isVisible = false
                    }
                }) {
                    Text("Отмена")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }

                Button(action: {
                    withAnimation {
                        isVisible = false
                    }
                    onConfirm() // Выполнение действия выхода
                }) {
                    Text("Понятно")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(UIColor.secondarySystemBackground)))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .frame(maxWidth: 300)
        .padding()
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            withAnimation(.spring()) {
                isVisible = true
            }
        }
    }
}


struct SecuritySettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isSeedPhraseVisible: Bool = false
    @State private var showingSetPasswordView = false
    @State private var isPasswordEnabled = false
    @State private var isBiometricsEnabled = false
    @State private var isCopied: Bool = false
    @State private var hasCheckedPasswordOnce = false
    @State private var showWarningBanner: Bool = false // Флаг для показа баннера
    @State private var hasAcknowledgedWarning: Bool = false // Указатель на подтверждение предупреждения

    var body: some View {
        VStack {
            // Заголовок для экрана "Безопасность"
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.blue)
                Text("Безопасность")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.top, 10)

            ScrollView {
                VStack(spacing: 20) {
                    // Настройка пароля
                    Section {
                        Toggle("Использовать код-пароль", isOn: $isPasswordEnabled)
                            .onChange(of: isPasswordEnabled) { value in
                                if value {
                                    if !authManager.isPasswordSet() {
                                        showingSetPasswordView = true
                                    }
                                } else {
                                    authManager.removePassword()
                                    isPasswordEnabled = false
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                    }

                    // Биометрия
                    Section {
                        Toggle("Использовать биометрию", isOn: $isBiometricsEnabled)
                            .onChange(of: isBiometricsEnabled) { value in
                                if value {
                                    authManager.authenticateWithBiometrics { success in
                                        if !success {
                                            isBiometricsEnabled = false
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                    }

                    // Показ сид-фразы
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            if showWarningBanner {
                                // Баннер с предупреждением
                                VStack(spacing: 10) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.title)
                                            .foregroundColor(.red)

                                        VStack(alignment: .leading, spacing: 5) {
                                            Text("Важно!")
                                                .font(.headline)
                                                .foregroundColor(.red)
                                            Text("Приложение fortify не несет ответственности за утерю seed-фразы.")
                                                .font(.footnote)
                                                .foregroundColor(.primary)
                                        }
                                    }

                                    Button(action: {
                                        withAnimation {
                                            showWarningBanner = false
                                            hasAcknowledgedWarning = true // Устанавливаем флаг подтверждения
                                            isSeedPhraseVisible = true // Показываем сид-фразу
                                        }
                                    }) {
                                        Text("Я понял")
                                            .fontWeight(.bold)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(Color.red.opacity(0.2))
                                            .foregroundColor(.red)
                                            .cornerRadius(10)
                                    }
                                }
                                .padding()
                                .background(Color(UIColor.systemGroupedBackground))
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                            } else {
                                // Отображение сид-фразы
                                LazyVGrid(
                                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                                    spacing: 15
                                ) {
                                    ForEach(authManager.seedPhrase.split(separator: " ").enumerated().map { $0 }, id: \.offset) { index, word in
                                        VStack(spacing: 5) {
                                            // Номер слова
                                            Text("\(index + 1).")
                                                .font(.caption)
                                                .foregroundColor(.gray)

                                            // Окошко слова
                                            ZStack {
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.2))
                                                    .frame(width: 100, height: 50)
                                                    .cornerRadius(8)
                                                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)

                                                if isSeedPhraseVisible {
                                                    Text(word)
                                                        .font(.system(.body, design: .monospaced))
                                                        .foregroundColor(.primary)
                                                } else {
                                                    Text("****")
                                                        .font(.system(.body, design: .monospaced))
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)

                                // Кнопки управления сид-фразой
                                HStack {
                                    Spacer()

                                    Button(action: {
                                        UIPasteboard.general.string = authManager.seedPhrase
                                        isCopied = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            isCopied = false
                                        }
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundColor(.blue)
                                    }

                                    Button(action: {
                                        if hasAcknowledgedWarning {
                                            // После подтверждения баннера просто переключаем видимость
                                            withAnimation {
                                                isSeedPhraseVisible.toggle()
                                            }
                                        } else {
                                            // Показываем баннер в первый раз
                                            withAnimation {
                                                showWarningBanner = true
                                                isSeedPhraseVisible = false
                                            }
                                        }
                                    }) {
                                        Image(systemName: isSeedPhraseVisible ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }

                            // Пояснительный текст
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                VStack(alignment: .leading) {
                                    Text("Сохраните сид-фразу")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Сохраните вашу сид-фразу в безопасном месте. Это ваш ключ к восстановлению доступа к аккаунту.")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.leading)
                        }
                    }
                }
                .padding()
            }
            .onAppear {
                if !hasCheckedPasswordOnce {
                    isPasswordEnabled = authManager.isPasswordSet()
                    hasCheckedPasswordOnce = true
                }
            }
            .sheet(isPresented: $showingSetPasswordView, onDismiss: {
                isPasswordEnabled = authManager.isPasswordSet()
            }) {
                SetPasswordView(isPresented: $showingSetPasswordView)
            }
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }
}

struct EditPasswordView: View {
    @Binding var isPresented: Bool
    var password: PasswordData
    var updatePassword: (String, String, String, String, String) -> Void

    @State private var service: String
    @State private var email: String
    @State private var username: String
    @State private var passwordValue: String
    @State private var isPasswordVisible = true

    init(isPresented: Binding<Bool>, password: PasswordData, updatePassword: @escaping (String, String, String, String, String) -> Void) {
        self._isPresented = isPresented
        self.password = password
        self.updatePassword = updatePassword
        _service = State(initialValue: password.service)
        _email = State(initialValue: password.email)
        _username = State(initialValue: password.username)
        _passwordValue = State(initialValue: password.password_value)
    }

    var body: some View {
        NavigationView {
            VStack {
                VStack {
                    CustomTextField(placeholder: "Сервис", text: $service)
                    CustomTextField(placeholder: "Email", text: $email)
                    CustomTextField(placeholder: "Имя пользователя", text: $username)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding([.leading, .trailing], 20)

                VStack {
                    HStack {
                        if isPasswordVisible {
                            TextField("Пароль", text: $passwordValue)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                        } else {
                            SecureField("Пароль", text: $passwordValue)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        Button(action: { isPasswordVisible.toggle() }) {
                            Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.blue)
                        }
                        .padding(.trailing, 5)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding([.leading, .trailing], 20)

                Spacer()

                Button(action: {
                    updatePassword(password.password_name, service, email, username, passwordValue)
                    isPresented = false
                }) {
                    Text("Сохранить изменения")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .padding([.leading, .trailing], 20)
                }
                .padding(.bottom, 20)
            }
            .navigationBarTitle("Редактировать пароль", displayMode: .inline)
            .navigationBarItems(leading: Button("Отмена") {
                isPresented = false
            })
        }
    }

    struct CustomTextField: View {
        var placeholder: String
        @Binding var text: String

        var body: some View {
            TextField(placeholder, text: $text)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                .padding(.bottom, 10)
        }
    }
}


// MARK: - SetPasswordView
struct SetPasswordView: View {
    @EnvironmentObject var authManager: AuthManager
    @Binding var isPresented: Bool
    @State private var firstEntry: [Int] = []
    @State private var secondEntry: [Int] = []
    @State private var isConfirming = false
    @State private var showMismatchAlert = false
    @State private var showSuccessAnimation = false
    
    private let codeLength = 6

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                
                Text(isConfirming ? "Подтвердите новый код-пароль" : "Введите новый код-пароль")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                
                HStack(spacing: 10) {
                    ForEach(0..<codeLength, id: \.self) { index in
                        Circle()
                            .frame(width: 15, height: 15)
                            .foregroundColor((isConfirming ? secondEntry : firstEntry).count > index ? .white : .clear)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                            )
                    }
                }
                .padding(.bottom, 60)
                
                Spacer()
                
                VStack(spacing: 15) {
                    ForEach(1...3, id: \.self) { row in
                        HStack(spacing: 15) {
                            ForEach(1...3, id: \.self) { column in
                                let number = (row - 1) * 3 + column
                                NumberButton(number: number, action: handleInput)
                            }
                        }
                    }
                    
                    HStack(spacing: 15) {
                        FaceIDButton(action: { /* Добавьте Face ID обработчик, если нужно */ })
                        
                        NumberButton(number: 0, action: handleInput)
                        
                        DeleteButton(action: deleteLastDigit)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 30)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.green]), startPoint: .top, endPoint: .bottom))
            .ignoresSafeArea()
            .alert(isPresented: $showMismatchAlert) {
                Alert(title: Text("Ошибка"), message: Text("Пароли не совпадают"), dismissButton: .default(Text("Ок")) {
                    resetEntries()
                })
            }
            
            // Показ финальной иконки "Успешно"
            if showSuccessAnimation {
                SuccessIconView()
                    .transition(.scale)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isPresented = false
                        }
                    }
            }
        }
    }
    
    // MARK: - Actions
    private func handleInput(_ number: Int) {
        withAnimation {
            if isConfirming {
                if secondEntry.count < codeLength {
                    secondEntry.append(number)
                }
                
                if secondEntry.count == codeLength {
                    verifyEntries()
                }
            } else {
                if firstEntry.count < codeLength {
                    firstEntry.append(number)
                }
                
                if firstEntry.count == codeLength {
                    isConfirming = true
                }
            }
        }
    }
    
    private func deleteLastDigit() {
        withAnimation {
            if isConfirming && !secondEntry.isEmpty {
                secondEntry.removeLast()
            } else if !firstEntry.isEmpty {
                firstEntry.removeLast()
            }
        }
    }
    
    private func verifyEntries() {
        if firstEntry == secondEntry {
            authManager.setPassword(firstEntry)
            withAnimation(.spring()) {
                showSuccessAnimation = true
            }
        } else {
            showMismatchAlert = true
        }
    }
    
    private func resetEntries() {
        firstEntry.removeAll()
        secondEntry.removeAll()
        isConfirming = false
    }
}

// MARK: - Success Icon View
struct SuccessIconView: View {
    @State private var scaleEffect: CGFloat = 0.0

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 100, height: 100)
            .foregroundColor(.green)
            .scaleEffect(scaleEffect)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.4, blendDuration: 0)) {
                    scaleEffect = 1.0
                }
            }
    }
}

struct LockScreenView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var enteredCode: [Int] = []
    @State private var isFaceIDEnabled = true
    @State private var isAnimatingOut = false
    @State private var shakeOffset: CGFloat = 0 // Смещение для дёргания замка
    
    private let codeLength = 6

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button(action: logout) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .padding(.top, 60)
                .padding(.trailing, 20)
            }
            
            Spacer()
            
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .padding()
                .foregroundColor(.white)
                .offset(x: shakeOffset)
            
            Text("Приложение заблокировано")
                .font(.title2)
                .foregroundColor(.white)
            
            HStack(spacing: 10) {
                ForEach(0..<codeLength, id: \.self) { index in
                    Circle()
                        .frame(width: 15, height: 15)
                        .foregroundColor(index < enteredCode.count ? .white : .clear)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                }
            }
            
            Spacer()
            
            VStack(spacing: 15) {
                ForEach(1...3, id: \.self) { row in
                    HStack(spacing: 15) {
                        ForEach(1...3, id: \.self) { column in
                            let number = (row - 1) * 3 + column
                            NumberButton(number: number, action: handleInput)
                        }
                    }
                }
                
                HStack(spacing: 15) {
                    if isFaceIDEnabled {
                        FaceIDButton(action: authenticateWithFaceID)
                    } else {
                        Spacer()
                    }
                    
                    NumberButton(number: 0, action: handleInput)
                    
                    DeleteButton(action: deleteLastDigit)
                }
            }
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.green]), startPoint: .top, endPoint: .bottom))
        .ignoresSafeArea()
        .offset(y: isAnimatingOut ? -UIScreen.main.bounds.height : 0)
        .opacity(isAnimatingOut ? 0 : 1)
        .onChange(of: authManager.isPasswordEntered) { newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.8)) {
                    isAnimatingOut = true
                }
            }
        }
    }
    
    // MARK: - Actions
    private func handleInput(_ number: Int) {
        withAnimation {
            if enteredCode.count < codeLength {
                enteredCode.append(number)
            }
            
            if enteredCode.count == codeLength {
                verifyCode()
            }
        }
    }
    
    private func deleteLastDigit() {
        withAnimation {
            if !enteredCode.isEmpty {
                enteredCode.removeLast()
            }
        }
    }
    
    private func verifyCode() {
        if authManager.verifyPassword(enteredCode) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                authManager.isPasswordEntered = true
            }
        } else {
            withAnimation {
                enteredCode.removeAll()
            }
            triggerShakeAnimation()
        }
    }
    
    private func authenticateWithFaceID() {
        authManager.authenticateWithBiometrics { success in
            if success {
                DispatchQueue.main.async {
                    authManager.isPasswordEntered = true
                }
            }
        }
    }
    
    private func logout() {
        authManager.logout()
    }
    
    // MARK: - Shake Animation
    
    private func triggerShakeAnimation() {
        let shakeSequence: [CGFloat] = [-10, 10, -8, 8, -5, 0]
        for (index, offset) in shakeSequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    shakeOffset = offset
                }
            }
        }
    }
}

struct NumberButton: View {
    let number: Int
    let action: (Int) -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            action(number)
        }) {
            Text("\(number)")
                .font(.title)
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(Color.blue.opacity(0.2))
                .clipShape(Circle())
                .shadow(radius: 5)
                .scaleEffect(isPressed ? 0.85 : 1.0) // Глубокое нажатие
        }
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4, blendDuration: 0.2)) {
                isPressed = pressing
            }
        }) {
            action(number)
        }
    }
}

struct DeleteButton: View {
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            action()
        }) {
            Text("Удалить")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(Color.red.opacity(0.2))
                .clipShape(Circle())
                .shadow(radius: 5)
                .scaleEffect(isPressed ? 0.85 : 1.0) // Глубокое нажатие
        }
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4, blendDuration: 0.2)) {
                isPressed = pressing
            }
        }) {
            action()
        }
    }
}

struct FaceIDButton: View {
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            action()
        }) {
            Image(systemName: "faceid")
                .font(.largeTitle)
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(Color.blue.opacity(0.2))
                .clipShape(Circle())
                .shadow(radius: 5)
                .scaleEffect(isPressed ? 0.85 : 1.0) // Глубокое нажатие
        }
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4, blendDuration: 0.2)) {
                isPressed = pressing
            }
        }) {
            action()
        }
    }
}

// MARK: - Folder Model и менеджер папок (локальное хранение)
struct Folder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    /// Храним цвет в hex, чтобы сохранять в UserDefaults
    var colorHex: String
}

/// Класс, управляющий папками и привязками паролей к папкам
class FolderManager: ObservableObject {
    static let shared = FolderManager()

    @Published var folders: [Folder] = []
    @Published var passwordFolderMap: [String: [UUID]] = [:]

    private let foldersKey = "foldersKey"
    private let folderMapKey = "folderMapKey"

    init() {
        loadFolders()
        loadFolderMap()
    }
    
    // Создание папки
    func createFolder(name: String, colorHex: String) {
        let newFolder = Folder(id: UUID(), name: name, colorHex: colorHex)
        folders.append(newFolder)
        saveFolders()
    }
    
    // Удаление папки
    func deleteFolder(_ folder: Folder) {
        folders.removeAll { $0.id == folder.id }
        // Убираем упоминания в passwordFolderMap
        for (key, folderIDs) in passwordFolderMap {
            passwordFolderMap[key] = folderIDs.filter { $0 != folder.id }
        }
        saveFolders()
        saveFolderMap()
    }
    
    // Редактирование папки
    func updateFolder(_ folder: Folder, newName: String, newColorHex: String) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[index].name = newName
        folders[index].colorHex = newColorHex
        saveFolders()
    }

    // Сохранение/загрузка
    private func saveFolders() {
        do {
            let data = try JSONEncoder().encode(folders)
            UserDefaults.standard.set(data, forKey: foldersKey)
        } catch {
            print("Ошибка при сохранении папок: \(error)")
        }
    }

    private func loadFolders() {
        guard let data = UserDefaults.standard.data(forKey: foldersKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([Folder].self, from: data)
            folders = decoded
        } catch {
            print("Ошибка при загрузке папок: \(error)")
        }
    }

    private func saveFolderMap() {
        do {
            let data = try JSONEncoder().encode(passwordFolderMap)
            UserDefaults.standard.set(data, forKey: folderMapKey)
        } catch {
            print("Ошибка при сохранении passwordFolderMap: \(error)")
        }
    }

    private func loadFolderMap() {
        guard let data = UserDefaults.standard.data(forKey: folderMapKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([String: [UUID]].self, from: data)
            passwordFolderMap = decoded
        } catch {
            print("Ошибка при загрузке passwordFolderMap: \(error)")
        }
    }

    // Добавление/удаление пароля в папку
    func togglePassword(_ passwordName: String, folderID: UUID) {
        var folderIDs = passwordFolderMap[passwordName] ?? []
        if folderIDs.contains(folderID) {
            folderIDs.removeAll { $0 == folderID }
        } else {
            folderIDs.append(folderID)
        }
        passwordFolderMap[passwordName] = folderIDs
        saveFolderMap()
    }
    
    // Проверка, есть ли пароль в папке
    func password(_ passwordName: String, isInFolder folderID: UUID) -> Bool {
        guard let folderIDs = passwordFolderMap[passwordName] else { return false }
        return folderIDs.contains(folderID)
    }
}

// MARK: - Утилита для перевода hex -> SwiftUI Color
extension Color {
    init?(hex: String) {
        let r, g, b: CGFloat
        var hexColor = hex
        if hexColor.hasPrefix("#") {
            hexColor.removeFirst()
        }
        
        guard hexColor.count == 6,
              let intCode = Int(hexColor, radix: 16) else {
            return nil
        }
        r = CGFloat((intCode >> 16) & 0xFF) / 255
        g = CGFloat((intCode >> 8) & 0xFF) / 255
        b = CGFloat(intCode & 0xFF) / 255
        
        self.init(red: r, green: g, blue: b)
    }
    
    /// Вернёт hex-строку без префикса `#`
    func toHex() -> String {
        let uiColor = UIColor(self)
        guard let components = uiColor.cgColor.components, components.count >= 3 else {
            return "FFFFFF"
        }
        let r = components[0]
        let g = components[1]
        let b = components[2]
        
        let rgb: Int =
          (Int)(r*255)<<16 |
          (Int)(g*255)<<8 |
          (Int)(b*255)<<0
        
        return String(format: "%06x", rgb)
    }
}

// MARK: - Экран управления папками
struct ManageFoldersView: View {
    @EnvironmentObject var folderManager: FolderManager
    @Environment(\.presentationMode) var presentationMode

    /// Флаг для показа окна «Создать папку»
    @State private var showCreateFolderSheet = false

    /// Папка, которую редактируем (nil — если не редактируем)
    @State private var folderToEdit: Folder? = nil

    var body: some View {
        NavigationView {
            VStack {
                if folderManager.folders.isEmpty {
                    Text("Папок ещё нет.\nНажмите «+» чтобы создать.")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List {
                        ForEach(folderManager.folders) { folder in
                            // 1) Можно использовать ZStack, чтобы наложить
                            // скруглённый фон + тень позади содержимого.
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: folder.colorHex) ?? .gray)
                                    .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)

                                // 2) Вложенный HStack для контента.
                                HStack {
                                    Text(folder.name)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()

                                    // Кнопка «Редактировать»
                                    Button(action: {
                                        folderToEdit = folder
                                    }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.white)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.trailing, 8)

                                    // Кнопка «Удалить»
                                    Button(action: {
                                        folderManager.deleteFolder(folder)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.white)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding() // Отступы внутри карточки
                            }
                            // 3) Убираем стандартный фон и разделители,
                            // чтобы видеть нашу «карточку».
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 4) // Чтобы карточки не слипались
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationBarTitle("Управление папками", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Закрыть") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(action: {
                    // Создать новую папку
                    showCreateFolderSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                }
            )
        }
        // Sheet для СОЗДАНИЯ папки
        .sheet(isPresented: $showCreateFolderSheet) {
            CreateOrEditFolderView(
                folderToEdit: nil,
                onDismiss: {
                    showCreateFolderSheet = false
                }
            )
            .environmentObject(folderManager)
        }
        // Sheet для РЕДАКТИРОВАНИЯ папки
        .sheet(item: $folderToEdit) { folder in
            CreateOrEditFolderView(
                folderToEdit: folder,
                onDismiss: {
                    folderToEdit = nil
                }
            )
            .environmentObject(folderManager)
        }
    }
}

// MARK: - Экран создания/редактирования папки
struct CreateOrEditFolderView: View {
    @EnvironmentObject var folderManager: FolderManager

    /// nil = создаём, не nil = редактируем
    let folderToEdit: Folder?

    /// Колбэк, вызываемый при закрытии
    let onDismiss: () -> Void

    @State private var folderName: String = ""
    @State private var selectedColorHex: String = "#ffffff"

    let pastelHexColors: [String] = [
        "#ffffff", "#ffd5cd", "#ffe8cc", "#fff5c6", "#d4f6cc",
        "#cffaf8", "#dce8fe", "#f8dcfe", "#ffd7f3", "#e9d7ff",
        "#f2d7d9", "#f3e8cb", "#eaf3d2", "#cce9e4", "#d6dff2", "#f3dae8", "#ffd5e5"
    ]

    var body: some View {
        NavigationView {
            VStack {
                Text(folderToEdit == nil ? "Создать папку" : "Редактировать папку")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 20)

                // Название папки
                TextField("Название папки", text: $folderName)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 10)

                Text("Выберите цвет:")
                    .fontWeight(.semibold)
                    .padding(.top, 15)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(pastelHexColors, id: \.self) { colorHex in
                            ZStack {
                                Circle()
                                    .fill(Color(hex: colorHex) ?? .gray)
                                    .frame(width: 40, height: 40)
                                    .padding(4)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColorHex == colorHex ? Color.blue : .clear, lineWidth: 2)
                                    )
                            }
                            .onTapGesture {
                                selectedColorHex = colorHex
                            }
                        }
                    }
                }
                .padding()

                Spacer()
            }
            .onAppear {
                if let folder = folderToEdit {
                    folderName = folder.name
                    selectedColorHex = folder.colorHex
                }
            }
            .navigationBarItems(
                leading: Button("Отмена") {
                    onDismiss()  // Закрываем sheet
                },
                trailing: Button(folderToEdit == nil ? "Создать" : "Сохранить") {
                    guard !folderName.isEmpty else { return }
                    if let folder = folderToEdit {
                        folderManager.updateFolder(folder, newName: folderName, newColorHex: selectedColorHex)
                    } else {
                        folderManager.createFolder(name: folderName, colorHex: selectedColorHex)
                    }
                    onDismiss()  // Закрываем sheet
                }
            )
        }
    }
}

// MARK: - Previews
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct PasswordGeneratorView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordGeneratorView()
    }
}

struct SavedPasswordsView_Previews: PreviewProvider {
    static var previews: some View {
        SavedPasswordsView()
    }
}
