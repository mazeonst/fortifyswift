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

    var body: some View {
            VStack {
                Spacer()

                Text("Добро пожаловать!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    registerUser()
                }) {
                    Text("Регистрация")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                .padding(.horizontal)
                .padding(.bottom, 10) // Уменьшили нижний отступ между кнопками

                Button(action: {
                    showLoginView = true
                }) {
                    Text("Вход")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                .padding(.horizontal)

                Spacer()

                Text("сид фраза восстановлению не подлежит")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()
            }
            .padding()
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
    }

// MARK: - Seed-фраза после регистрации
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
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 20)
            
            // Сид-фраза с возможностью скрыть или показать
            VStack(spacing: 15) {
                HStack {
                    if isSeedVisible {
                        Text(seedPhrase)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
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
                            .font(.system(size: 22))
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
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
                .shadow(radius: 5)
            }
            .padding(.horizontal, 20)

            // Уведомление о копировании
            if isCopied {
                Text("Скопировано!")
                    .font(.caption)
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
            
            Spacer()
            
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
                    .shadow(radius: 5)
            }
            .padding(.horizontal, 20)
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }
}


struct LoginView: View {
    @State private var seedPhrase: String = ""
    @State private var password: String = "" // Поле для пароля
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @State private var isSeedVisible: Bool = false
    @State private var loginError: Bool = false
    @State private var showLoading: Bool = false

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 30) {
                // Заголовок
                Text("Вход")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 50)
                    .foregroundColor(Color(.label)) // Динамический цвет текста

                // Поля ввода для сид-фразы и пароля
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
                                .shadow(radius: 5)
                        } else {
                            SecureField("Введите сид-фразу", text: $seedPhrase)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground)) // Динамический цвет фона
                                .foregroundColor(Color(.label)) // Динамический цвет текста
                                .cornerRadius(12)
                                .shadow(radius: 5)
                        }

                        Button(action: {
                            withAnimation {
                                isSeedVisible.toggle()
                            }
                        }) {
                            Image(systemName: isSeedVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.blue)
                                .padding(.trailing, 10)
                        }
                    }
                }
                .padding(.horizontal, 20)
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
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30) // Располагаем кнопку внизу
                }

                // Ошибка при неверной сид-фразе или пароле
                if loginError {
                    Text("Неверная сид-фраза или пароль. Попробуйте снова.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 10)
                        .transition(.opacity)
                }
            }
        }
    }

    func loginUser() {
        guard let url = URL(string: "http://localhost:8000/login") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Формируем тело запроса
        let body: [String: String] = ["seed": seedPhrase, "password": password]

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
                    Form {
                        Section(header: Text("Настройки генерации")) {
                            TextField("Количество паролей", text: $numberOfPasswords)
                                .keyboardType(.numberPad)
                            TextField("Длина пароля", text: $passwordLength)
                                .keyboardType(.numberPad)
                            Toggle(isOn: $useUppercase) {
                                Text("Использовать заглавные буквы")
                            }
                            Toggle(isOn: $useNumbers) {
                                Text("Использовать цифры")
                            }
                            Toggle(isOn: $useSpecialCharacters) {
                                Text("Использовать специальные символы")
                            }
                            Button(action: {
                                generatePasswords()
                            }) {
                                Text("Сгенерировать")
                                    .fontWeight(.bold)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(12)
                                    .shadow(radius: 5)
                            }
                        }
                        
                        Section(header: Text("Сгенерированные пароли")) {
                            ForEach(generatedPasswords, id: \.self) { password in
                                HStack {
                                    Text(password)
                                    Spacer()
                                    // Кнопка для копирования пароля
                                    Button(action: {
                                        copyToClipboard(text: password) // Действие для копирования
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(PlainButtonStyle()) // Отключаем стандартную анимацию нажатия, чтобы избежать конфликтов

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
                        }
                    }
                }
                .navigationTitle("Генератор паролей")
            }
        }
        .sheet(isPresented: $showSavePasswordView) {
            SavePasswordView(isPresented: $showSavePasswordView, currentPassword: $selectedPassword, saveAction: savePassword)
                .environmentObject(authManager) // Передаем authManager в SavePasswordView
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
                Form {
                    Section(header: Text("Данные о пароле")) {
                        CustomTextField(placeholder: "Сервис", text: $service)
                        CustomTextField(placeholder: "Email", text: $email)
                        CustomTextField(placeholder: "Username", text: $username)
                    }

                    Section(header: Text("Пароль")) {
                        HStack {
                            Text(currentPassword)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.gray)
                                .padding()
                                .background(Color.gray.opacity(0.1))
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
                .padding(.top, 20)
                
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
    @State private var searchText: String = "" // Состояние для текста поиска
    @State private var isSearching: Bool = false // Для анимации поиска

    var body: some View {
        NavigationView {
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
                .padding(.top, 10)

                // Проверяем, пуст ли список сохраненных паролей
                if savedPasswords.isEmpty {
                    VStack {
                        Spacer()
                        
                        Image(systemName: "tray")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100) // Размер изображения
                            .foregroundColor(.gray)
                            .padding(.bottom, 20)
                        
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
                }
            }
            .navigationTitle("Сохраненные пароли")
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

    func loadPasswords() {
        guard let url = URL(string: "http://localhost:8000/get_passwords?seed=\(authManager.seedPhrase)") else {
            print("Неверный URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Ошибка загрузки данных: \(error)")
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
                print("Ошибка декодирования: \(error)")
            }
        }.resume()
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
