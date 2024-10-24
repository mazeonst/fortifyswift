import SwiftUI
import UIKit
import MessageUI

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

@main
struct PasswordGeneratorApp: App {
    @StateObject var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            if authManager.isLoggedIn {
                ContentView()
                    .environmentObject(authManager)
                    .preferredColorScheme(.none) // Автоматическое переключение между светлой и темной темами
            } else {
                WelcomeView()
                    .environmentObject(authManager)
                    .preferredColorScheme(.none) // Автоматическое переключение между светлой и темной темами
            }
        }
    }
}

// MARK: - Управление авторизацией и Seed-фразой
class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var seedPhrase: String = ""
    
    private let seedPhraseKey = "userSeedPhrase"
    
    init() {
        // При инициализации проверяем, есть ли сохранённая сид-фраза
        if let savedSeed = UserDefaults.standard.string(forKey: seedPhraseKey) {
            self.seedPhrase = savedSeed
            self.isLoggedIn = true
        }
    }
    
    func login(with seed: String) {
        self.seedPhrase = seed
        self.isLoggedIn = true
        // Сохраняем сид-фразу в UserDefaults
        UserDefaults.standard.set(seed, forKey: seedPhraseKey)
    }

    func logout() {
        self.seedPhrase = ""
        self.isLoggedIn = false
        // Очищаем сид-фразу из UserDefaults при выходе
        UserDefaults.standard.removeObject(forKey: seedPhraseKey)
    }
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
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
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
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Копировать")
                }
                .fontWeight(.bold)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 20)

            // Анимация "Сохраните свою сид-фразу"
            Spacer()
            SaveSeedPhraseAnimationView() // Анимация

            // Кнопка продолжить
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

import SwiftUI

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
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    // Убираем лишний отступ сверху для секции настроек
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
                        Toggle(isOn: $useUppercase) {
                            Text("Использовать заглавные буквы")
                        }
                        .padding(.top, 10)
                        Toggle(isOn: $useNumbers) {
                            Text("Использовать цифры")
                        }
                        .padding(.top, 10)
                        Toggle(isOn: $useSpecialCharacters) {
                            Text("Использовать специальные символы")
                        }
                        .padding(.top, 10)

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
                    .background(Color(UIColor.systemBackground)) // Системный фон для адаптации к теме
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding([.leading, .trailing], 20)

                    // Секция с карточками для сгенерированных паролей
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
                                            copyToClipboard(text: password) // Действие для копирования
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(PlainButtonStyle()) // Отключаем стандартную анимацию нажатия

                                        // Кнопка для сохранения пароля
                                        Button(action: {
                                            selectedPassword = password
                                            showSavePasswordView = true // Действие для открытия окна сохранения
                                        }) {
                                            Image(systemName: "square.and.arrow.down")
                                                .foregroundColor(.green)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding()
                                .background(Color(UIColor.systemBackground)) // Системный фон для адаптации к теме
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                .padding([.leading, .trailing], 20)
                            }
                        }
                        .padding(.bottom, 80) // Отступ, чтобы не заезжать за таб-бар
                    }
                }
                .navigationTitle("Генератор паролей")
            }
        }
        .sheet(isPresented: $showSavePasswordView) {
            SavePasswordView(isPresented: $showSavePasswordView, currentPassword: $selectedPassword, saveAction: savePassword)
                .environmentObject(authManager)
        }
    }
    
    func generatePasswords() {
        guard let num = Int(numberOfPasswords), let length = Int(passwordLength) else { return }
        generatedPasswords = (0..<num).map { _ in
            generatePassword(length: length)
        }
    }
    
    func generatePassword(length: Int) -> String {
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
    
    func copyToClipboard(text: String) {
        UIPasteboard.general.string = text
        showCopiedAlert = true
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
            .navigationTitle("Сохраненные")
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
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(password.service)
                    .font(.headline)
                    .foregroundColor(Color(.label)) // Динамический цвет для заголовка
                Spacer()
                Button(action: {
                    withAnimation {
                        isPasswordVisible.toggle()
                    }
                }) {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundColor(.blue)
                }
            }
            
            if isPasswordVisible {
                Text("Логин: \(password.username)")
                    .font(.subheadline)
                    .foregroundColor(Color(.secondaryLabel)) // Динамический цвет для второстепенного текста
                
                Text(password.password_value)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Color(.label)) // Динамический цвет для пароля
            } else {
                Text("Пароль скрыт")
                    .font(.subheadline)
                    .foregroundColor(Color(.secondaryLabel)) // Динамический цвет для скрытого текста
            }

            HStack {
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
                    Text("Копировать")
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                if isCopied {
                    Text("Скопировано!")
                        .font(.caption)
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }

            Button(action: {
                deletePassword()
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    Text("Удалить")
                        .foregroundColor(.red)
                }
            }
            .padding(.top, 5)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground)) // Динамический фон для карточки
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }


    // Функция для отправки запроса на удаление пароля
    func deletePassword() {
        guard let url = URL(string: "http://localhost:8000/delete_password") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Данные для отправки на сервер
        let body: [String: Any] = [
            "seed": authManager.seedPhrase,
            "password_name": password.password_name
        ]

        // Преобразуем словарь в JSON
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
                    // Удаляем пароль из списка на клиенте
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
    @State private var showingMailView = false // Для отображения почтового экрана
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil
    @State private var isCopied: Bool = false // Для отображения состояния копирования

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Другие настройки
                        Section {
                            Toggle("Использовать биометрию", isOn: .constant(false))
                                .toggleStyle(SwitchToggleStyle(tint: Color(UIColor.systemBlue))) // Системный цвет для тумблера
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground)) // Динамический фон
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

                        Section {
                            HStack {
                                if isSeedPhraseVisible {
                                    Text(authManager.seedPhrase)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(Color(.label)) // Динамический цвет для текста
                                } else {
                                    Text("**********")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(Color(.secondaryLabel)) // Динамический цвет для скрытого текста
                                }

                                Spacer()

                                // Кнопка для копирования
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

                                // Кнопка для отображения/скрытия пароля
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
                        .background(Color(UIColor.secondarySystemBackground)) // Динамический фон
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
                            .background(Color(UIColor.secondarySystemBackground)) // Динамический фон
                            .cornerRadius(10)
                            .shadow(radius: 5)
                        }
                    }
                    .padding()
                }

                // Кнопка "Выйти из аккаунта" закреплена внизу
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
                .background(Color(UIColor.secondarySystemBackground)) // Динамический фон
                .cornerRadius(10)
                .shadow(color: Color.red.opacity(0.2), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
                .padding(.bottom, 20) // Отступ снизу для кнопки
            }
            .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all)) // Фон страницы
            .sheet(isPresented: $showingMailView) {
                MailView(result: self.$mailResult) // Открытие экрана почты
            }
            .navigationTitle("Настройки")

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
