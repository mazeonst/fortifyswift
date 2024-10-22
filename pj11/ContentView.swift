import SwiftUI
import UIKit

@main
struct FortifyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
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
                        }

                        // Кнопка генерации
                        Section {
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
                        .listRowBackground(Color.clear) // Убираем фон от списка для кнопки

                        // Список сгенерированных паролей
                        Section(header: Text("Сгенерированные пароли")) {
                            ForEach(generatedPasswords, id: \.self) { password in
                                HStack {
                                    Text(password)
                                    Spacer()
                                    Button(action: {
                                        copyToClipboard(password: password)
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    Button(action: {
                                        savePassword(password: password)
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

            // Всплывающее уведомление для устройств без Dynamic Island
            if showCopiedAlert {
                ToastView(message: "Пароль скопирован в буфер обмена")
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

            // Анимация для устройств с Dynamic Island
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

    func copyToClipboard(password: String) {
        UIPasteboard.general.string = password
        if hasDynamicIsland() {
            showDynamicIslandAnimation()
        } else {
            showBottomAlert()
        }
    }

    func savePassword(password: String) {
        // Сохранение пароля с дополнительными данными
    }

    func hasDynamicIsland() -> Bool {
        return UIDevice.current.name.contains("iPhone 14 Pro") ||
               UIDevice.current.name.contains("iPhone 15") ||
               UIDevice.current.name.contains("iPhone 16")
    }

    func showDynamicIslandAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            dynamicIslandVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                dynamicIslandVisible = false
            }
        }
    }

    func showBottomAlert() {
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

// MARK: - Сохраненные пароли
struct SavedPasswordsView: View {
    @State private var savedPasswords: [SavedPassword] = []

    var body: some View {
        NavigationView {
            List(savedPasswords) { password in
                NavigationLink(destination: PasswordDetailView(password: password)) {
                    Text(password.service)
                }
            }
            .navigationTitle("Сохраненные пароли")
        }
    }
}

struct PasswordDetailView: View {
    let password: SavedPassword

    var body: some View {
        Form {
            Text("Сервис: \(password.service)")
            Text("Email: \(password.email)")
            Text("Username: \(password.username)")
            HStack {
                Text("Пароль: \(password.password)")
                Spacer()
                Button(action: {
                    UIPasteboard.general.string = password.password
                }) {
                    Image(systemName: "doc.on.doc")
                }
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

