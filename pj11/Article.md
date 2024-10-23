import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            WelcomeView(selectedTab: $selectedTab)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Приветственный экран
struct WelcomeView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Fortify")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            NavigationLink(destination: RegistrationView(selectedTab: $selectedTab)) {
                Text("Зарегистрироваться")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            NavigationLink(destination: RestoreView(selectedTab: $selectedTab)) {
                Text("Восстановить")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Экран регистрации
struct RegistrationView: View {
    @Binding var selectedTab: Int
    @State private var seedPhrase: [String] = []
    @State private var showCopiedAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Как это работает?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()

                Text("Система работает на основе сид-фразы. Сид-фраза состоит из 16 случайных слов, которые являются ключом к вашим данным. Обязательно сохраните сид-фразу.")
                    .multilineTextAlignment(.center)
                    .padding()

                Button(action: {
                    generateSeedPhrase()
                }) {
                    Text("Показать сид-фразу")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                if !seedPhrase.isEmpty {
                    HStack(spacing: 20) {
                        VStack(spacing: 10) {
                            ForEach(0..<8, id: \.self) { i in
                                Text(seedPhrase[i])
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }

                        VStack(spacing: 10) {
                            ForEach(8..<16, id: \.self) { i in
                                Text(seedPhrase[i])
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Button(action: {
                        copySeedPhraseToClipboard()
                    }) {
                        Text("Скопировать")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }

                Spacer()

                Button(action: {
                    selectedTab = 0
                }) {
                    Text("Продолжить")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
        }
    }
    
    func generateSeedPhrase() {
        let words = ["apple", "orange", "banana", "grape", "lemon", "strawberry", "blueberry", "melon", "kiwi", "peach", "plum", "cherry", "lime", "pear", "mango", "pineapple"]
        seedPhrase = Array(words.shuffled().prefix(16))
    }
    
    func copySeedPhraseToClipboard() {
        let phrase = seedPhrase.joined(separator: ", ")
        UIPasteboard.general.string = phrase
        showCopiedAlert = true
    }
}

// MARK: - Экран восстановления
struct RestoreView: View {
    @Binding var selectedTab: Int
    @State private var enteredSeed: [String] = Array(repeating: "", count: 16)
    let savedSeedPhrase = ["apple", "orange", "banana", "grape", "lemon", "strawberry", "blueberry", "melon", "kiwi", "peach", "plum", "cherry", "lime", "pear", "mango", "pineapple"]
    @State private var isSeedCorrect = false
    @State private var showError = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Введите вашу сид-фразу")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()

                HStack(spacing: 20) {
                    VStack(spacing: 10) {
                        ForEach(0..<8, id: \.self) { i in
                            TextField("Слово \(i + 1)", text: $enteredSeed[i])
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }

                    VStack(spacing: 10) {
                        ForEach(8..<16, id: \.self) { i in
                            TextField("Слово \(i + 1)", text: $enteredSeed[i])
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)

                Button(action: {
                    restoreAccount()
                }) {
                    Text("Восстановить")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSeedCorrect ? Color.green : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                if showError {
                    Text("Ошибка: неверная сид-фраза")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    func restoreAccount() {
        if enteredSeed == savedSeedPhrase {
            isSeedCorrect = true
            showError = false
            selectedTab = 1
        } else {
            isSeedCorrect = false
            showError = true
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
    @State private var dynamicIslandVisible = false
    @State private var selectedPassword = ""
    @State private var showSavePasswordView = false
    @State private var copiedMessage = ""

    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    Form {
                        Section(header: Text("Настройки генерации")) {
                            TextField("Количество паролей", text: $numberOfPasswords)
                                .keyboardType(.numberPad)
                                .onChange(of: numberOfPasswords) { newValue in
                                    numberOfPasswords = newValue.filter { $0.isNumber }
                                }
                            TextField("Длина пароля", text: $passwordLength)
                                .keyboardType(.numberPad)
                                .onChange(of: passwordLength) { newValue in
                                    passwordLength = newValue.filter { $0.isNumber }
                                }
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
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .shadow(radius: 10)
                            }
                        }

                        Section(header: Text("Сгенерированные пароли")) {
                            ForEach(generatedPasswords, id: \.self) { password in
                                HStack {
                                    Text(password)
                                    Spacer()
                                    Button(action: {
                                        copyToClipboard(text: password, message: "Пароль скопирован в буфер обмена")
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    Button(action: {
                                        selectedPassword = password
                                        showSavePasswordView = true
                                    }) {
                                        Image(systemName: "square.and.arrow.down")
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Генератор паролей")
            }

            if showCopiedAlert {
                ToastView(message: copiedMessage)
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showCopiedAlert = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCopiedAlert = false
                            }
                        }
                    }
            }

            if dynamicIslandVisible {
                DynamicIslandView()
                    .zIndex(2)
                    .transition(.scale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dynamicIslandVisible = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                dynamicIslandVisible = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showSavePasswordView) {
            SavePasswordView(isPresented: $showSavePasswordView, currentPassword: $selectedPassword, saveAction: savePassword)
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

    func copyToClipboard(text: String, message: String) {
        UIPasteboard.general.string = text
        copiedMessage = message
        withAnimation(.easeInOut(duration: 0.3)) {
            showCopiedAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCopiedAlert = false
            }
        }
    }

    func savePassword(service: String, email: String, username: String, password: String) {
        SavedPasswordManager.shared.addPassword(service: service, email: email, username: username, password: password)
    }
}

// MARK: - Сохраненные пароли
struct SavedPasswordsView: View {
    @ObservedObject var passwordManager = SavedPasswordManager.shared
    @State private var searchText = ""
    @State private var showCopiedAlert = false
    @State private var copiedMessage = ""

    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Поиск по сервисам", text: $searchText)
                            .padding(7)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal, 10)
                    }
                    .padding()

                    List(filteredPasswords, id: \.id) { savedPassword in
                        NavigationLink(destination: PasswordDetailView(password: savedPassword, showCopiedAlert: $showCopiedAlert, copiedMessage: $copiedMessage)) {
                            Text(savedPassword.service)
                        }
                    }
                    .navigationTitle("Сохраненные пароли")
                }
            }

            if showCopiedAlert {
                ToastView(message: copiedMessage)
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showCopiedAlert = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCopiedAlert = false
                            }
                        }
                    }
            }
        }
    }

    var filteredPasswords: [SavedPassword] {
        if searchText.isEmpty {
            return passwordManager.savedPasswords
        } else {
            return passwordManager.savedPasswords.filter { $0.service.localizedCaseInsensitiveContains(searchText) }
        }
    }
}

// MARK: - Password Detail View for editing and copying password
struct PasswordDetailView: View {
    @ObservedObject var passwordManager = SavedPasswordManager.shared
    @State var password: SavedPassword
    @Binding var showCopiedAlert: Bool
    @Binding var copiedMessage: String

    var body: some View {
        Form {
            Section(header: Text("Сервис")) {
                HStack {
                    TextField("Сервис", text: $password.service)
                        .onChange(of: password.service) { _ in updatePassword() }
                    Spacer()
                    Button(action: {
                        copyToClipboard(text: password.service, message: "Сервис скопирован в буфер обмена")
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }

            Section(header: Text("Email")) {
                HStack {
                    TextField("Email", text: $password.email)
                        .onChange(of: password.email) { _ in updatePassword() }
                    Spacer()
                    Button(action: {
                        copyToClipboard(text: password.email, message: "Email скопирован в буфер обмена")
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }

            Section(header: Text("Username")) {
                HStack {
                    TextField("Username", text: $password.username)
                        .onChange(of: password.username) { _ in updatePassword() }
                    Spacer()
                    Button(action: {
                        copyToClipboard(text: password.username, message: "Username скопирован в буфер обмена")
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }

            Section(header: Text("Пароль")) {
                HStack {
                    Text(password.password)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Button(action: {
                        copyToClipboard(text: password.password, message: "Пароль скопирован в буфер обмена")
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
        .navigationTitle(password.service)
    }

    func updatePassword() {
        if let index = passwordManager.savedPasswords.firstIndex(where: { $0.id == password.id }) {
            passwordManager.savedPasswords[index] = password
        }
    }

    func copyToClipboard(text: String, message: String) {
        UIPasteboard.general.string = text
        copiedMessage = message
        withAnimation(.easeInOut(duration: 0.3)) {
            showCopiedAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCopiedAlert = false
            }
        }
    }
}

// MARK: - Модель данных для сохраненного пароля
struct SavedPassword: Identifiable {
    var id = UUID()
    var service: String
    var email: String
    var username: String
    var password: String
}

class SavedPasswordManager: ObservableObject {
    static let shared = SavedPasswordManager()
    @Published var savedPasswords: [SavedPassword] = []

    func addPassword(service: String, email: String, username: String, password: String) {
        let newPassword = SavedPassword(service: service, email: email, username: username, password: password)
        savedPasswords.append(newPassword)
    }
}

// MARK: - Dynamic Island анимация
struct DynamicIslandView: View {
    var body: some View {
        HStack {
            Image(systemName: "doc.on.doc.fill")
                .foregroundColor(.white)
            Text("Пароль скопирован!")
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.black)
        .cornerRadius(12)
        .frame(width: 200, height: 50)
    }
}

// MARK: - Всплывающее уведомление снизу экрана
struct ToastView: View {
    var message: String

    var body: some View {
        Text(message)
            .padding()
            .background(Color.black.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

// MARK: - Сохранение пароля
struct SavePasswordView: View {
    @Binding var isPresented: Bool
    @Binding var currentPassword: String
    var saveAction: (String, String, String, String) -> Void

    @State private var service = ""
    @State private var email = ""
    @State private var username = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Сервис")) {
                    TextField("Сервис", text: $service)
                    TextField("Email", text: $email)
                    TextField("Username", text: $username)
                }

                Section(header: Text("Пароль")) {
                    Text(currentPassword)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .navigationBarTitle("Сохранить пароль", displayMode: .inline)
            .navigationBarItems(leading: Button("Отмена") {
                isPresented = false
            }, trailing: Button("Сохранить") {
                saveAction(service, email, username, currentPassword)
                isPresented = false
            })
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





//
//  pj11App.swift
//  pj11
//
//  Created by Michael Mirmikov on 10.10.2024.
//

import SwiftUI

@main
struct pj11App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}




---------

import SwiftUI
import UIKit

@main
struct PasswordGeneratorApp: App {
    @StateObject var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            if authManager.isLoggedIn {
                ContentView() // Главный экран после авторизации
                    .environmentObject(authManager)
            } else {
                WelcomeView() // Экран входа/регистрации
                    .environmentObject(authManager)
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
            Button(action: {
                registerUser()
            }) {
                Text("Регистрация")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()

            Button(action: {
                showLoginView = true
            }) {
                Text("Вход")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
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

    var body: some View {
        VStack {
            Text("Ваша сид-фраза:")
                .font(.headline)
            Text(seedPhrase)
                .font(.system(.body, design: .monospaced))
                .padding()
                .border(Color.gray, width: 2)
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = seedPhrase
                    }) {
                        Text("Копировать")
                        Image(systemName: "doc.on.doc")
                    }
                }

            Button(action: {
                // Сохраняем seed-фразу и переходим на главный экран
                authManager.login(with: seedPhrase)
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Продолжить")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
        .padding()
    }
}

// MARK: - Экран Вход
struct LoginView: View {
    @State private var seedPhrase: String = ""
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        VStack {
            TextField("Введите сид-фразу", text: $seedPhrase)
                .padding()
                .border(Color.gray, width: 2)
            
            Button(action: {
                loginUser()
            }) {
                Text("Войти")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
        .padding()
    }
    
    func loginUser() {
        guard let url = URL(string: "http://localhost:8000/login") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Формируем тело запроса
        let body: [String: String] = ["seed": seedPhrase]
        
        do {
            // Преобразуем тело запроса в JSON
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
            request.httpBody = jsonData
        } catch {
            print("Ошибка сериализации JSON: \(error)")
            return
        }
        
        // Отладочное сообщение для проверки отправляемого JSON
        if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
            print("Отправленный JSON: \(jsonString)")  // Убедитесь, что строка сид-фразы правильно передана
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Ошибка запроса: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP код ответа: \(httpResponse.statusCode)")
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
                    // Обработка ошибок
                    let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                    if let firstError = errorResponse.detail.first {
                        print("Ошибка: \(firstError.msg)")
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
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        
                        Section(header: Text("Сгенерированные пароли")) {
                            ForEach(generatedPasswords, id: \.self) { password in
                                HStack {
                                    Text(password)
                                    Spacer()
                                    Button(action: {
                                        copyToClipboard(text: password)
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    Button(action: {
                                        selectedPassword = password
                                        showSavePasswordView = true
                                    }) {
                                        Image(systemName: "square.and.arrow.down")
                                    }
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
            Form {
                Section(header: Text("Сервис")) {
                    TextField("Сервис", text: $service)
                    TextField("Email", text: $email)
                    TextField("Username", text: $username)
                }

                Section(header: Text("Пароль")) {
                    Text(currentPassword)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .navigationBarTitle("Сохранить пароль", displayMode: .inline)
            .navigationBarItems(leading: Button("Отмена") {
                isPresented = false
            }, trailing: Button("Сохранить") {
                saveAction(service, email, username, currentPassword)
                isPresented = false
            })
        }
    }
}

// MARK: - Отображение сохранённых паролей
struct SavedPasswordsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var savedPasswords: [PasswordData] = []
    
    var body: some View {
        NavigationView {
            List(savedPasswords, id: \.password_name) { password in
                VStack(alignment: .leading) {
                    Text(password.service).font(.headline)
                    Text("Логин: \(password.username)").font(.subheadline)
                    Text("Пароль: \(password.password_value)").font(.system(.body, design: .monospaced))
                }
            }
            .navigationTitle("Сохраненные пароли")
            .onAppear(perform: loadPasswords)
        }
    }
    
    func loadPasswords() {
        // Загрузка паролей с сервера по текущей сид-фразе
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
                // Декодируем данные с сервера
                let decodedResponse = try JSONDecoder().decode(PasswordsResponse.self, from: data)
                DispatchQueue.main.async {
                    print("Загруженные пароли: \(decodedResponse.passwords)")
                    self.savedPasswords = decodedResponse.passwords // Обновляем состояние с паролями
                }
            } catch {
                print("Ошибка декодирования: \(error)")
            }
        }.resume()
    }
}
struct PasswordsResponse: Codable {
    let passwords: [PasswordData]
}

struct PasswordData: Codable {
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

// MARK: - Настройки — отображение текущей Seed-фразы
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Общие")) {
                    Toggle("Использовать биометрию", isOn: .constant(false)) // Пока не используется
                }
                
                Section(header: Text("Seed-фраза")) {
                    Text(authManager.seedPhrase)
                        .font(.system(.body, design: .monospaced))
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = authManager.seedPhrase
                            }) {
                                Text("Копировать")
                                Image(systemName: "doc.on.doc")
                            }
                        }
                }
                
                Section {
                    Button(action: {
                        authManager.logout() // Выход из аккаунта
                    }) {
                        Text("Выйти из аккаунта")
                            .foregroundColor(.red)
                    }
                }
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
        vc.setToRecipients(["fortify@icloud.com"])
        vc.setSubject("Поддержка Fortify")
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
                    .preferredColorScheme(.none)
            } else {
                WelcomeView()
                    .environmentObject(authManager)
                    .preferredColorScheme(.none)
            }
        }
    }
}

class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var seedPhrase: String = ""
    
    private let seedPhraseKey = "userSeedPhrase"
    
    init() {
        if let savedSeed = UserDefaults.standard.string(forKey: seedPhraseKey) {
            self.seedPhrase = savedSeed
            self.isLoggedIn = true
        }
    }
    
    func login(with seed: String) {
        self.seedPhrase = seed
        self.isLoggedIn = true
        UserDefaults.standard.set(seed, forKey: seedPhraseKey)
    }

    func logout() {
        self.seedPhrase = ""
        self.isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: seedPhraseKey)
    }
}

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
                .padding(.bottom, 10)

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

struct SeedPhraseView: View {
    @Binding var seedPhrase: String
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @State private var isSeedVisible: Bool = false
    @State private var isCopied: Bool = false

    var body: some View {
        VStack(spacing: 30) {
            Text("Ваша сид-фраза")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 20)
            
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

            if isCopied {
                Text("Скопировано!")
                    .font(.caption)
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
            
            Spacer()
            
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
        vc.setToRecipients(["fortify@icloud.com"])
        vc.setSubject("Поддержка Fortify")
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
                    .preferredColorScheme(.none)
            } else {
                WelcomeView()
                    .environmentObject(authManager)
                    .preferredColorScheme(.none)
            }
        }
    }
}

class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var seedPhrase: String = ""
    
    private let seedPhraseKey = "userSeedPhrase"
    
    init() {
        if let savedSeed = UserDefaults.standard.string(forKey: seedPhraseKey) {
            self.seedPhrase = savedSeed
            self.isLoggedIn = true
        }
    }
    
    func login(with seed: String) {
        self.seedPhrase = seed
        self.isLoggedIn = true
        UserDefaults.standard.set(seed, forKey: seedPhraseKey)
    }

    func logout() {
        self.seedPhrase = ""
        self.isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: seedPhraseKey)
    }
}

struct WelcomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showSeedPhrase = false
    @State private var seedPhrase: String = ""
    @State private var showLoginView = false

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Spacer()

                Text("Добро пожаловать!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(radius: 10)

                Spacer()

                Button(action: {
                    registerUser()
                }) {
                    Text("Регистрация")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .shadow(radius: 10)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)

                Button(action: {
                    showLoginView = true
                }) {
                    Text("Вход")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .shadow(radius: 10)
                }
                .padding(.horizontal)

                Spacer()

                Text("Сид фраза восстановлению не подлежит")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))

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

struct SeedPhraseView: View {
    @Binding var seedPhrase: String
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @State private var isSeedVisible: Bool = false
    @State private var isCopied: Bool = false

    var body: some View {
        VStack(spacing: 30) {
            Text("Ваша сид-фраза")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 20)
                .foregroundColor(.white)

            VStack(spacing: 15) {
                HStack {
                    if isSeedVisible {
                        Text(seedPhrase)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                    } else {
                        Text("********")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            isSeedVisible.toggle()
                        }
                    }) {
                        Image(systemName: isSeedVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 22))
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            }

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
                .background(Color.white.opacity(0.2))
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(radius: 10)
            }
            .padding(.horizontal, 20)

            if isCopied {
                Text("Скопировано!")
                    .font(.caption)
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
            
            Spacer()
            
            Button(action: {
                authManager.login(with: seedPhrase)
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Продолжить")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 10)
            }
            .padding(.horizontal, 20)
        }
        .padding()
        .background(LinearGradient(gradient: Gradient(colors: [Color.purple, Color.black]), startPoint: .topLeading, endPoint: .bottomTrailing).edgesIgnoringSafeArea(.all))
    }
}

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
        .accentColor(.purple)
    }
}

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
            LinearGradient(gradient: Gradient(colors: [Color.black, Color.purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)

            NavigationView {
                VStack(spacing: 20) {
                    Form {
                        Section(header: Text("Настройки генерации").foregroundColor(.white)) {
                            TextField("Количество паролей", text: $numberOfPasswords)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                            TextField("Длина пароля", text: $passwordLength)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                            Toggle(isOn: $useUppercase) {
                                Text("Использовать заглавные буквы").foregroundColor(.white)
                            }
                            Toggle(isOn: $useNumbers) {
                                Text("Использовать цифры").foregroundColor(.white)
                            }
                            Toggle(isOn: $useSpecialCharacters) {
                                Text("Использовать специальные символы").foregroundColor(.white)
                            }
                            Button(action: {
                                generatePasswords()
                            }) {
                                Text("Сгенерировать")
                                    .fontWeight(.bold)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.purple.opacity(0.7))
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                                    .shadow(radius: 10)
                            }
                        }
                        
                        Section(header: Text("Сгенерированные пароли").foregroundColor(.white)) {
                            ForEach(generatedPasswords, id: \ .self) { password in
                                HStack {
                                    Text(password)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button(action: {
                                        copyToClipboard(text: password)
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    Button(action: {
                                        selectedPassword = password
                                        showSavePasswordView = true
                                    }) {
                                        Image(systemName: "square.and.arrow.down")
                                            .foregroundColor(.green)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .padding(.horizontal)
                }
                .navigationTitle("Генератор паролей")
                .foregroundColor(.white)
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
        guard let url = URL(string: "http://localhost:8000/save_password") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let passwordData = PasswordData(password_name: "NewPassword", password_value: password, service: service, email: email, username: username)
        
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
        }.resume()
    }
}
