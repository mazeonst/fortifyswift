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
////////////////////куаукпукукпукп  куп ук п ук пукук
///ук
///п
///
@main
struct PasswordGeneratorApp: App {
    @StateObject var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            if authManager.isLoggedIn {
                if authManager.isPasswordEntered {
                    ContentView()
                        .environmentObject(authManager)
                        .preferredColorScheme(.none) // Автоматическое переключение между светлой и темной темами
                } else {
                    LockScreenView() // Новый экран блокировки
                        .environmentObject(authManager)
                        .preferredColorScheme(.none)
                }
            } else {
                WelcomeView()
                    .environmentObject(authManager)
                    .preferredColorScheme(.none) // Автоматическое переключение между светлой и темной темами
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
        
        // Если пароль установлен, задаём isPasswordEntered в false, иначе пропускаем LockScreenView
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
        
        // Получаем сохранённый пароль как строку и преобразуем его в массив цифр
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
        vc.setSubject("Поддержка Fortify") // Тема письма
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
    @State private var isAnimating = false
    @State private var currentSloganIndex = 0 // Для отслеживания текущего слогана

    let slogans = [
        "Генерация сложных паролей",
        "Безопасный менеджмент паролей",
        "Удобство хранения"
    ]

    var body: some View {
        VStack {
            Spacer()

            // Название приложения Fortify с технологичным шрифтом
            Text("Fortify")
                .font(.system(size: 44, weight: .heavy, design: .rounded)) // Технологичный и жирный шрифт
                .foregroundColor(.blue)
                .padding(.bottom, 10)
                .scaleEffect(isAnimating ? 1 : 0.9)
                .opacity(isAnimating ? 1 : 0.7)
                .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isAnimating)
                .onAppear {
                    isAnimating = true
                }

            // Слоганы с анимацией, расположены по центру
            ZStack {
                ForEach(0..<slogans.count, id: \.self) { index in
                    AnimatedSloganView(text: slogans[index], index: index, currentSloganIndex: $currentSloganIndex)
                }
            }
            .frame(height: UIScreen.main.bounds.height * 0.3)
            .onAppear {
                startSloganRotation()
            }

            Spacer()

            // Кнопка "Регистрация"
            Button(action: {
                registerUser()
            }) {
                Text("Регистрация")
                    .font(.system(size: 20, weight: .bold, design: .rounded)) // Стильный и жирный шрифт
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.5)]), startPoint: .top, endPoint: .bottom))
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .shadow(color: Color.blue.opacity(0.5), radius: 10, x: 0, y: 5)
                    .scaleEffect(isAnimating ? 1.05 : 1)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
            .animation(.easeInOut(duration: 0.2), value: isAnimating)

            // Кнопка "Вход"
            Button(action: {
                showLoginView = true
            }) {
                Text("Вход")
                    .font(.system(size: 20, weight: .bold, design: .rounded)) // Технологичный и современный шрифт
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green.opacity(0.5)]), startPoint: .top, endPoint: .bottom))
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .shadow(color: Color.green.opacity(0.5), radius: 10, x: 0, y: 5)
                    .scaleEffect(isAnimating ? 1.05 : 1)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
            .animation(.easeInOut(duration: 0.2), value: isAnimating)

            Spacer()
        }
        .padding()
        .background(LinearGradient(gradient: Gradient(colors: [Color.white, Color.blue.opacity(0.1)]), startPoint: .top, endPoint: .bottom)) // Фон
        .edgesIgnoringSafeArea(.all) // Фон на весь экран
        .sheet(isPresented: $showSeedPhrase) {
            SeedPhraseView(seedPhrase: $seedPhrase)
        }
        .sheet(isPresented: $showLoginView) {
            LoginView()
        }
    }
    
        func registerUser() {
            guard let url = URL(string: "http://localhost:8000/register") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let data = data {
                    let response = try? JSONDecoder().decode([String: String].self, from: data)
                    if let response = response, let seed = response["seed"] {
                        DispatchQueue.main.async {
                            self.seedPhrase = seed
                            self.showSeedPhrase = true
                        }
                    }
                }
            }.resume()
        }
    
    // Запуск бесконечной ротации слоганов
        func startSloganRotation() {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                withAnimation(Animation.easeInOut(duration: 1.5)) {
                    currentSloganIndex = (currentSloganIndex + 1) % slogans.count
                }
            }
        }
    }

// Вспомогательная структура для создания анимаций слоганов
struct AnimatedSloganView: View {
    var text: String
    var index: Int
    @Binding var currentSloganIndex: Int

    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .bold, design: .rounded)) // Жирный и технологичный шрифт для слоганов
            .foregroundColor(.blue)
            .opacity(currentSloganIndex == index ? 1 : 0)
            .offset(x: currentSloganIndex == index ? 0 : 100)
            .rotationEffect(.degrees(currentSloganIndex == index ? 0 : 10))
            .animation(.spring(response: 0.8, dampingFraction: 0.5), value: currentSloganIndex)
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
            
            // Сид-фраза с возможностью скрыть или показать
            VStack(spacing: 15) {
                HStack {
                    if isSeedVisible {
                        Text(seedPhrase)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                            .shadow(color: .blue.opacity(0.2), radius: 5, x: 0, y: 5)
                    } else {
                        Text("********")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Кнопка "Глазик" для показа/скрытия
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
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
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
                    .frame(width: 60, height: 60)
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
    @State private var seedPhrase: String = ""
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @State private var isSeedVisible: Bool = false
    @State private var loginError: Bool = false
    @State private var showLoading: Bool = false
    @State private var isButtonPressed = false // Для анимации кнопки
    @State private var colorChange = false // Для переливающегося заголовка
    @State private var currentIconIndex = 0 // Для анимации иконок

    let icons = [
        ("lock.shield.fill", "Безопасность"),
        ("key.fill", "Шифрование"),
        ("hand.raised.fill", "Приватность")
    ]

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 30) {
                // Переливающийся заголовок (статичный)
                Text("Вход")
                    .font(.system(size: 30, weight: .heavy, design: .rounded)) // Статичный заголовок с большим размером
                    .fontWeight(.bold)
                    .padding(.top, 30)
                    .foregroundColor(colorChange ? Color.blue : Color.green)
                    .onAppear {
                        colorChange.toggle()
                    }

                // Поле ввода для сид-фразы
                VStack(alignment: .leading, spacing: 15) {
                    Text("Введите вашу сид-фразу:")
                        .font(.headline)
                        .foregroundColor(Color(.secondaryLabel)) // Динамический цвет для метки

                    HStack {
                        if isSeedVisible {
                            TextField("Введите сид-фразу", text: $seedPhrase)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground)) // Динамический цвет фона
                                .foregroundColor(Color(.label)) // Динамический цвет текста
                                .cornerRadius(12)
                                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5) // Тень с анимацией
                        } else {
                            SecureField("Введите сид-фразу", text: $seedPhrase)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground)) // Динамический цвет фона
                                .foregroundColor(Color(.label)) // Динамический цвет текста
                                .cornerRadius(12)
                                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5) // Тень с анимацией
                        }

                        // Кнопка "Глазик" для показа/скрытия
                        Button(action: {
                            withAnimation {
                                isSeedVisible.toggle()
                            }
                        }) {
                            Image(systemName: isSeedVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.blue)
                                .padding(.trailing, 5)
                        }

                        // Кнопка "Вставить" для вставки текста из буфера обмена
                        Button(action: {
                            if let clipboardText = UIPasteboard.general.string {
                                seedPhrase = clipboardText
                            }
                        }) {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.blue)
                                .padding(.trailing, 10)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Анимированные иконки безопасности (очень большие иконки на весь оставшийся экран)
                ZStack {
                    ForEach(0..<icons.count, id: \.self) { index in
                        AnimatedIconView(icon: icons[index].0, text: icons[index].1, index: index, currentIconIndex: $currentIconIndex)
                    }
                }
                .frame(height: UIScreen.main.bounds.height * 0.4) // Занимает значительную часть экрана
                .onAppear {
                    startIconRotation()
                }

                Spacer()

                if showLoading {
                    ProgressView()
                        .padding()
                } else {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.5, blendDuration: 0.3)) {
                            isButtonPressed.toggle()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                isButtonPressed = false
                                loginUser()
                            }
                        }
                    }) {
                        Text("Войти")
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                            .shadow(color: isButtonPressed ? .blue.opacity(0.7) : .blue.opacity(0.5), radius: 10, x: 0, y: 5) // Анимация тени при нажатии
                            .scaleEffect(isButtonPressed ? 0.95 : 1.0) // Анимация уменьшения при нажатии
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30) // Располагаем кнопку внизу
                }

                // Ошибка при неверной сид-фразе или пароле
                if loginError {
                    Text("Неверная сид-фраза. Попробуйте снова.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 10)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: loginError)
                }
            }
        }
    }

    // Запуск бесконечной ротации иконок
    func startIconRotation() {
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            withAnimation(Animation.easeInOut(duration: 1.5)) {
                currentIconIndex = (currentIconIndex + 1) % icons.count
            }
        }
    }

    func loginUser() {
        guard let url = URL(string: "http://localhost:8000/login") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Формируем тело запроса
        let body: [String: String] = ["seed": seedPhrase]

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
                // Проверим, что это успешный ответ, и выведем сообщение
                if let responseJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
                let message = responseJSON["message"] {
                    print("Сообщение от сервера: \(message)")
                    // Успешный вход
                    DispatchQueue.main.async {
                        authManager.login(with: seedPhrase)
                        presentationMode.wrappedValue.dismiss() // Закрываем экран логина
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
                .frame(width: UIScreen.main.bounds.width * 0.5, height: UIScreen.main.bounds.width * 0.5) // Очень большие иконки
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
                    
                    VStack {
                        HStack {
                            
                            VStack {
                                TextField("Количество паролей", text: $numberOfPasswords)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(8)
                                
                                TextField("Длина пароля", text: $passwordLength)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(8)
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

                        Toggle(isOn: $useUppercase) {
                            Text("Использовать заглавные буквы")
                        }
                        .padding(.top, 10)
                        .onChange(of: useUppercase) { _ in updatePasswordStrength() }

                        Toggle(isOn: $useNumbers) {
                            Text("Использовать цифры")
                        }
                        .padding(.top, 10)
                        .onChange(of: useNumbers) { _ in updatePasswordStrength() }

                        Toggle(isOn: $useSpecialCharacters) {
                            Text("Использовать специальные символы")
                        }
                        .padding(.top, 10)
                        .onChange(of: useSpecialCharacters) { _ in updatePasswordStrength() }

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
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding([.leading, .trailing], 20)

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
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                .padding([.leading, .trailing], 20)
                            }
                        }
                        .padding(.bottom, 80)
                    }
                }
            }
        }
        .sheet(isPresented: $showSavePasswordView) {
            SavePasswordView(isPresented: $showSavePasswordView, currentPassword: $selectedPassword, saveAction: savePassword)
                .environmentObject(authManager)
        }
    }
    func savePassword(service: String, email: String, username: String, password: String) {
            // Отправка пароля на сервер для сохранения
            guard let url = URL(string: "http://localhost:8000/save_password") else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let passwordData = PasswordData(password_name: "NewPassword", password_value: password, service: service, email: email, username: username)
            
            // Преобразуем структуру в словарь
            let body: [String: Any] = [
                "seed": authManager.seedPhrase,
                "password_data": passwordData.toDictionary() // Используем преобразование в словарь
            ]
            
            // Преобразуем словарь в JSON
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
    

    private func generatePasswords() {
        guard let num = Int(numberOfPasswords), let length = Int(passwordLength) else { return }
        generatedPasswords = (0..<num).map { _ in generatePassword(length: length) }
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

    private func updatePasswordStrength() {
        guard let length = Int(passwordLength) else {
            passwordStrengthPercentage = 0
            return
        }

        // Если длина пароля менее 8 символов, устанавливаем 0% независимо от других параметров
        if length < 8 {
            withAnimation(.spring()) {
                passwordStrengthPercentage = 0
            }
            return
        }

        // Дальнейший расчет для длины 8 и более символов
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

        // Ограничение силы пароля до 100%
        withAnimation(.spring()) {
            passwordStrengthPercentage = min(strength, 100)
        }
    }


    
    private func copyToClipboard(text: String) {
        UIPasteboard.general.string = text
        showCopiedAlert = true
    }
}

// Круговая диаграмма силы пароля
struct CircleChartView: View {
    @Binding var percentage: Double

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: CGFloat(percentage / 100))
                .stroke(percentage < 40 ? Color.red : (percentage < 80 ? Color.yellow : Color.green), style: StrokeStyle(lineWidth: 24, lineCap: .round))
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
    @State private var savedPasswords: [PasswordData] = []
    @State private var showAddPasswordView = false // Для отображения формы добавления пароля
    @State private var searchText: String = "" // Состояние для текста поиска
    @State private var isSearching: Bool = false // Для анимации поиска

    var body: some View {
        NavigationView {
            ZStack { // Используем ZStack для наложения кнопки поверх контента
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
                    // Поле поиска с анимацией
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
                                    hideKeyboard() // Скрываем клавиатуру
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

                    // Проверяем, пуст ли список сохраненных паролей
                    if savedPasswords.isEmpty {
                        VStack {
                            Spacer()

                            Image(systemName: "tray")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100) // Размер изображения
                                .foregroundColor(.gray)
                                .padding(.bottom, 0)

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
                                        .transition(.opacity) // Анимация появления/исчезновения
                                        .animation(.easeInOut(duration: 0.4), value: filteredPasswords) // Применяем анимацию при изменении списка
                                }
                            }
                        }
                        .padding(.top, 10)
                    }
                }

                // Кнопка добавления в правом нижнем углу
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showAddPasswordView = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 34)) // Устанавливаем размер иконки
                                .foregroundColor(.green)
                                .padding()
                        }
                        .sheet(isPresented: $showAddPasswordView) {
                            AddPasswordView(isPresented: $showAddPasswordView, savePassword: savePassword)
                        }
                    }
                    .padding([.trailing, .bottom], 10) // Добавляем отступы от края
                }
            }
            .onAppear(perform: loadPasswords)
        }
    }
    
    var filteredPasswords: [PasswordData] {
        if searchText.isEmpty {
            return savedPasswords
        } else {
            return savedPasswords.filter { $0.service.localizedCaseInsensitiveContains(searchText) }
        }
    }

    // Функция для сохранения пользовательских паролей
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

            // Отправляем запрос на сервер
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Ошибка запроса: \(error)")
                    return
                }

                // Обновляем список паролей после сохранения
                DispatchQueue.main.async {
                    loadPasswords()
                }
            }.resume()
        }

        // Функция для загрузки паролей
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
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

// MARK: - Карточка пароля
struct PasswordCardView: View {
    let password: PasswordData
    @Binding var savedPasswords: [PasswordData]
    @State private var isPasswordVisible: Bool = false
    @State private var isCopied: Bool = false
    @State private var showEditPasswordView = false
    @EnvironmentObject var authManager: AuthManager

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
        .background(Color(UIColor.secondarySystemBackground)) // Динамический фон для карточки
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showEditPasswordView) {
            EditPasswordView(
                isPresented: $showEditPasswordView,
                password: password,
                updatePassword: { name, service, email, username, newValue in
                    updatePassword(passwordName: name, service: service, email: email, username: username, newPasswordValue: newValue)
                }
            )
        }
    }

    func updatePassword(passwordName: String, service: String, email: String, username: String, newPasswordValue: String) {
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
    @State private var isSeedPhraseVisible: Bool = false
    @State private var showingMailView = false
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil
    @State private var isCopied: Bool = false
    @State private var showingSetPasswordView = false
    @State private var isPasswordEnabled = false
    @State private var isBiometricsEnabled = false
    @State private var hasCheckedPasswordOnce = false

    var body: some View {
        NavigationView {
            VStack {
                // Новый заголовок для настройки
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
                        // Настройка пароля
                        Section {
                            Toggle("Использовать код-пароль", isOn: $isPasswordEnabled)
                                .onChange(of: isPasswordEnabled) { value in
                                    if value && !authManager.isPasswordSet() {
                                        showingSetPasswordView = true
                                    } else if !value {
                                        authManager.removePassword()
                                        isPasswordEnabled = false
                                    }
                                }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
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
                                .toggleStyle(SwitchToggleStyle(tint: Color(UIColor.systemBlue)))
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // Показ сид-фразы
                        Section {
                            HStack {
                                if isSeedPhraseVisible {
                                    Text(authManager.seedPhrase)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(Color(.label))
                                } else {
                                    Text("**********")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(Color(.secondaryLabel))
                                }
                                
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
                                .padding(.trailing, 10)
                                
                                Button(action: {
                                    withAnimation {
                                        isSeedPhraseVisible.toggle()
                                    }
                                }) {
                                    Image(systemName: isSeedPhraseVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = authManager.seedPhrase
                                }) {
                                    Text("Копировать")
                                    Image(systemName: "doc.on.doc")
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
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
                    authManager.logout()
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
            .sheet(isPresented: $showingSetPasswordView) {
                SetPasswordView(isPresented: $showingSetPasswordView)
                    .onDisappear {
                        isPasswordEnabled = authManager.isPasswordSet()
                    }
            }
        }
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
