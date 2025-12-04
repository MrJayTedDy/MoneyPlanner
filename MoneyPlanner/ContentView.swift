import SwiftUI
import SwiftData
import Charts

// --- LOCALIZATION (Embedded) ---
struct L10n {
    static var isUkrainian: Bool {
        Locale.current.language.languageCode?.identifier == "uk"
    }
    
    static func get(_ key: String) -> String {
        if isUkrainian {
            return ukrainianStrings[key] ?? key
        }
        return key // Return key as English text (default)
    }
    
    static let ukrainianStrings: [String: String] = [
        "Planner": "Планування",
        "History": "Історія",
        "Newest": "Новіші",
        "Oldest": "Старіші",
        "Most Expensive": "Найдорожчі",
        "Cheapest": "Найдешевші",
        "All": "Всі",
        "Paid": "Оплачено",
        "Unpaid": "Не оплачено",
        "Manage Categories": "Керувати категоріями",
        "Rate:": "Курс:",
        "Income": "Надходження",
        "Add Income": "Додати дохід",
        "Expenses List": "Список витрат",
        "No expenses. Click 'Add' to start.": "Немає витрат. Натисніть 'Додати', щоб почати.",
        "Add Expense": "Додати витрату",
        "Savings Top-up": "Поповнення скарбнички",
        "Add Savings": "Відкласти кошти",
        "Budget:": "Бюджет:",
        "Expenses:": "Витрати:",
        "Savings:": "Збереження:",
        "Remaining:": "Залишок:",
        "Expense Structure": "Структура витрат",
        "Essential": "Важливо",
        "Needed": "Потрібно",
        "Want": "Хотілка",
        "No Data": "Немає даних",
        "Total": "Всього",
        "Manage": "Керувати",
        "Accumulated:": "Накопичено:",
        "+ This month:": "+ Цього місяця:",
        "Finish Month": "Завершити місяць",
        "Archive is empty": "Архів порожній",
        "Clear": "Очистити",
        "No expenses for selected filters": "Немає витрат за обраними фільтрами",
        "Details missing": "Деталі відсутні",
        "No data for chart": "Немає даних для діаграми",
        "By Category": "По категоріях",
        "By Priority": "За важливістю",
        "Category Name": "Назва категорії",
        "Restore Default Categories": "Відновити стандартні категорії",
        "Manage Categories Title": "Управління категоріями",
        "Done": "Готово",
        "+ Add": "+ Додати",
        "Manage Savings": "Керування Скарбничкою",
        "Balance:": "Баланс:",
        "Withdraw": "Зняти",
        "Deposit": "Покласти",
        "Cancel": "Скасувати",
        "Name": "Назва",
        "Expense Name": "Назва витрати",
        "Category": "Категорія",
        "Priority": "Пріоритет",
        "Amount": "Сума",
        "View": "Вид",
        "List": "Список",
        "Charts": "Діаграми",
        "Status:": "Статус:",
        "Expense Filter:": "Фільтр витрат:",
        "New Source": "Нове джерело",
        "New Category": "Нова категорія",
        "Other": "Інше",
        "Type": "Тип",
        "Sorting": "Сортування"
    ]
}

// Types for sorting and filtering
enum SortOption: String, CaseIterable, Identifiable {
    case dateDesc = "Newest"
    case dateAsc = "Oldest"
    case amountDesc = "Most Expensive"
    case amountAsc = "Cheapest"
    
    var id: String { rawValue }
    
    var localizedName: String {
        L10n.get(rawValue)
    }
}

enum FilterStatus: String, CaseIterable, Identifiable {
    case all = "All"
    case paid = "Paid"
    case unpaid = "Unpaid"
    
    var id: String { rawValue }
    
    var localizedName: String {
        L10n.get(rawValue)
    }
}

struct ContentView: View {
    // --- 1. DATABASE ---
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \IncomeItem.dateAdded) private var incomeSources: [IncomeItem]
    
    // Active expenses
    @Query(filter: #Predicate<ExpenseItem> { $0.monthHistory == nil && $0.categoryName != "savings" }, sort: \ExpenseItem.dateAdded, order: .reverse)
    private var activeExpenses: [ExpenseItem]
    
    @Query(sort: \CategoryItem.order) private var categories: [CategoryItem]
    
    @Query(filter: #Predicate<ExpenseItem> { $0.monthHistory == nil && $0.categoryName == "savings" }, sort: \ExpenseItem.dateAdded)
    private var savingsGoals: [ExpenseItem]
    
    @Query(sort: \MonthHistory.date, order: .reverse) private var history: [MonthHistory]
    
    // --- 2. SETTINGS ---
    @AppStorage("exchangeRate") private var exchangeRate: Double = 41.5
    @AppStorage("totalAccumulatedSavings") private var totalAccumulatedSavings: Double = 0
    
    @State private var selectedTab = 0
    
    // Modal sheets
    @State private var showSavingsManager = false
    @State private var showCategoryManager = false
    @State private var manualAmount: Double = 0
    @State private var manualIsUSD: Bool = true
    
    // Date selection
    @State private var selectedMonthIndex: Int = Calendar.current.component(.month, from: Date()) - 1
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var expandedYears: Set<Int> = [Calendar.current.component(.year, from: Date())]
    
    // History
    @State private var expandedHistoryMonths: Set<UUID> = []
    @State private var historyViewType: Int = 0
    
    // History filters (global)
    @State private var filterEssential: Bool = true
    @State private var filterNeededNow: Bool = true
    @State private var filterWant: Bool = true
    
    // Chart settings
    @State private var chartFilterEssential: Bool = true
    @State private var chartFilterNeeded: Bool = true
    @State private var chartFilterWant: Bool = true
    @State private var selectedChartAngle: Double?
    
    // --- NEW: Sorting and filtering in planner ---
    @State private var sortOption: SortOption = .dateDesc
    @State private var filterStatus: FilterStatus = .all
    
    // Dynamic month names based on locale
    var months: [String] {
        Calendar.current.monthSymbols
    }
    
    let years = Array(2024...2030)
    
    // --- 3. LOGIC ---
    
    // Computed property for on-the-fly sorting and filtering
    var processedExpenses: [ExpenseItem] {
        // 1. Filtering
        let filtered = activeExpenses.filter { item in
            switch filterStatus {
            case .all: return true
            case .paid: return item.isPaid
            case .unpaid: return !item.isPaid
            }
        }
        
        // 2. Sorting
        return filtered.sorted { item1, item2 in
            switch sortOption {
            case .dateDesc:
                return item1.dateAdded > item2.dateAdded
            case .dateAsc:
                return item1.dateAdded < item2.dateAdded
            case .amountDesc:
                let amt1 = toUAH(amount: item1.amount, isUSD: item1.isUSD)
                let amt2 = toUAH(amount: item2.amount, isUSD: item2.isUSD)
                return amt1 > amt2
            case .amountAsc:
                let amt1 = toUAH(amount: item1.amount, isUSD: item1.isUSD)
                let amt2 = toUAH(amount: item2.amount, isUSD: item2.isUSD)
                return amt1 < amt2
            }
        }
    }
    
    func checkFirstLaunch() {
        if categories.isEmpty {
            // Default categories (using keys, they will be saved as is, but could be localized on display if needed)
            // For simplicity, we save localized names based on first launch language
            let defaults = L10n.isUkrainian
                ? ["Продукти", "Житло", "Транспорт", "Розваги", "Здоров'я", "Основні", "Інше"]
                : ["Food", "Housing", "Transport", "Entertainment", "Health", "Essentials", "Other"]
            
            for (index, name) in defaults.enumerated() {
                modelContext.insert(CategoryItem(name: name, order: index))
            }
        }
    }
    
    func toUAH(amount: Double, isUSD: Bool) -> Double {
        return isUSD ? amount * exchangeRate : amount
    }
    
    var totalIncomeUAH: Double {
        incomeSources.reduce(0) { $0 + toUAH(amount: $1.amount, isUSD: $1.isUSD) }
    }
    
    var totalExpensesUAH: Double {
        activeExpenses.reduce(0) { $0 + toUAH(amount: $1.amount, isUSD: $1.isUSD) }
    }
    
    var totalSavings: Double {
        savingsGoals.reduce(0) { $0 + toUAH(amount: $1.amount, isUSD: $1.isUSD) }
    }
    
    var totalSpent: Double { totalExpensesUAH + totalSavings }
    var remainingBalance: Double { totalIncomeUAH - totalSpent }
    
    struct YearGroup: Identifiable {
        let id: Int
        var records: [MonthHistory]
    }
    
    var historyByYear: [YearGroup] {
        let grouped = Dictionary(grouping: history) { record in
            Calendar.current.component(.year, from: record.date)
        }
        return grouped.map { YearGroup(id: $0.key, records: $0.value) }
            .sorted { $0.id > $1.id }
    }
    
    func color(for priority: Priority) -> Color {
        switch priority {
        case .essential: return .red
        case .neededNow: return .orange
        case .want: return .blue
        }
    }
    
    // UI Helper for Priority Localization
    func priorityName(_ priority: Priority) -> String {
        switch priority {
        case .essential: return L10n.get("Essential")
        case .neededNow: return L10n.get("Needed")
        case .want: return L10n.get("Want")
        }
    }
    
    // --- 4. UI ---
    var body: some View {
        TabView(selection: $selectedTab) {
            plannerView
                .tabItem { Label(L10n.get("Planner"), systemImage: "pencil.and.ruler") }
                .tag(0)
            
            historyView
                .tabItem { Label(L10n.get("History"), systemImage: "clock") }
                .tag(1)
        }
        #if os(macOS)
        .padding()
        .frame(minWidth: 1000, minHeight: 700)
        #endif
        .sheet(isPresented: $showSavingsManager) { savingsManagerSheet }
        .sheet(isPresented: $showCategoryManager) { categoryManagerSheet }
        .onAppear(perform: checkFirstLaunch)
    }
    
    // --- PLANNER ---
    var plannerView: some View {
        Group {
            #if os(macOS)
            HSplitView {
                leftPanelInputs.frame(minWidth: 550)
                rightPanelSummary.padding().frame(minWidth: 320)
            }
            #else
            VStack(spacing: 0) {
                rightPanelSummary.padding().background(Color.secondary.opacity(0.1))
                Divider()
                leftPanelInputs
            }
            #endif
        }
    }
    
    var leftPanelInputs: some View {
        VStack(spacing: 0) {
            // Control panel
            GroupBox {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "calendar").foregroundStyle(.blue)
                        Picker("", selection: $selectedMonthIndex) {
                            ForEach(0..<12) { index in Text(months[index]).tag(index) }
                        }
                        #if os(macOS)
                        .frame(width: 110)
                        #endif
                        Picker("", selection: $selectedYear) {
                            ForEach(years, id: \.self) { year in Text(String(year)).tag(year) }
                        }
                        .frame(width: 80)
                        
                        Spacer()
                        
                        Button(action: { showCategoryManager = true }) {
                            Label(L10n.get("Manage Categories"), systemImage: "tag")
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                    
                    #if os(macOS)
                    Divider()
                    #endif
                    
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.blue)
                        Text(L10n.get("Rate:"))
                        TextField("0", value: $exchangeRate, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 60).multilineTextAlignment(.center)
                        Text("UAH/USD").foregroundStyle(.secondary).font(.caption)
                        Spacer()
                    }
                }
            }
            .padding()
            
            List {
                Section(header: incomeHeader) {
                    ForEach(incomeSources) { item in incomeRowView(item: item) }
                        .onDelete { idx in idx.forEach { modelContext.delete(incomeSources[$0]) } }
                    Button("+ \(L10n.get("Add Income"))") { modelContext.insert(IncomeItem(name: L10n.get("New Source"), amount: 0, isUSD: true)) }
                }
                
                // Expense section with new filter
                Section(header: expensesHeaderWithFilters) {
                    if activeExpenses.isEmpty {
                        Text(L10n.get("No expenses. Click 'Add' to start."))
                            .foregroundStyle(.secondary).italic()
                    } else {
                        // Using processedExpenses instead of activeExpenses
                        ForEach(processedExpenses) { item in
                            expenseRowView(item: item)
                        }
                        .onDelete { idx in
                            // Since we are filtering/sorting, indices don't match.
                            // Delete by ID
                            idx.forEach { index in
                                let itemToDelete = processedExpenses[index]
                                modelContext.delete(itemToDelete)
                            }
                        }
                    }
                    Button("+ \(L10n.get("Add Expense"))") {
                        let defaultCat = categories.first?.name ?? L10n.get("Other")
                        modelContext.insert(ExpenseItem(name: "", amount: 0, categoryName: defaultCat, isUSD: false, priority: .essential))
                    }
                }
                
                Section(header: savingsHeader) {
                    ForEach(savingsGoals) { item in incomeRowView(item: item) }
                        .onDelete { idx in idx.forEach { modelContext.delete(savingsGoals[$0]) } }
                    Button("+ \(L10n.get("Add Savings"))") { modelContext.insert(ExpenseItem(name: "", amount: 0, categoryName: "savings", isUSD: false)) }
                }
            }
            .listStyle(.inset)
        }
    }
    
    // --- RIGHT PANEL (UPDATED CHART) ---
    var rightPanelSummary: some View {
        VStack(alignment: .leading, spacing: 15) {
            #if os(macOS)
            Text("\(L10n.get("Budget:")) \(months[selectedMonthIndex]) \(String(selectedYear))").font(.headline)
            Divider()
            #endif
            
            Group {
                HStack { Text(L10n.get("Income:")); Spacer(); Text("\(totalIncomeUAH, specifier: "%.0f")").bold().foregroundStyle(.green) }
                
                HStack { Text(L10n.get("Expenses:")); Spacer(); Text("-\(totalExpensesUAH, specifier: "%.0f")").foregroundStyle(.red) }
                HStack { Text(L10n.get("Savings:")); Spacer(); Text("-\(totalSavings, specifier: "%.0f")").foregroundStyle(.blue) }
                
                #if os(macOS)
                Divider()
                #endif
                HStack(alignment: .lastTextBaseline) {
                    Text(L10n.get("Remaining:")).font(.title3)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(remainingBalance, specifier: "%.0f") ₴").font(.title3).bold()
                            .foregroundStyle(remainingBalance >= 0 ? .green : .red)
                        Text("≈ \((remainingBalance / exchangeRate), specifier: "%.0f") $").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            
            Divider()
            
            // --- NEW CHART BLOCK ---
            VStack(alignment: .center, spacing: 10) {
                HStack {
                    Text(L10n.get("Expense Structure")).font(.caption).bold().foregroundStyle(.secondary)
                    Spacer()
                }
                
                // 1. Filters below the chart
                HStack(spacing: 8) {
                    Toggle(L10n.get("Essential"), isOn: $chartFilterEssential)
                        .toggleStyle(.button).tint(.red)
                    Toggle(L10n.get("Needed"), isOn: $chartFilterNeeded)
                        .toggleStyle(.button).tint(.orange)
                    Toggle(L10n.get("Want"), isOn: $chartFilterWant)
                        .toggleStyle(.button).tint(.blue)
                }
                .controlSize(.mini)
                .labelStyle(.titleOnly)
                
                // 2. Preparing data for the chart
                let filteredForChart = activeExpenses.filter { exp in
                    if exp.priority == .essential && !chartFilterEssential { return false }
                    if exp.priority == .neededNow && !chartFilterNeeded { return false }
                    if exp.priority == .want && !chartFilterWant { return false }
                    return true
                }
                
                if filteredForChart.isEmpty {
                    ContentUnavailableView(L10n.get("No Data"), systemImage: "chart.pie")
                        .frame(height: 200)
                } else {
                    // Grouping
                    let groupedData = Dictionary(grouping: filteredForChart, by: { $0.categoryName })
                        .map { (key, value) -> (category: String, total: Double) in
                            (key, value.reduce(0) { $0 + toUAH(amount: $1.amount, isUSD: $1.isUSD) })
                        }
                        .sorted { $0.total > $1.total }
                    
                    let totalFiltered = groupedData.reduce(0) { $0 + $1.total }
                    
                    // Calculate the selected item IN ADVANCE to use in Chart
                    let selectedItem = getSelectedCategory(data: groupedData, total: totalFiltered)
                    
                    // 3. Interactive chart
                    ZStack {
                        Chart(groupedData, id: \.category) { item in
                            SectorMark(
                                angle: .value("Amount", item.total),
                                innerRadius: .ratio(0.65), // Making a "donut"
                                angularInset: 2.0
                            )
                            .cornerRadius(5)
                            .foregroundStyle(by: .value("Category", item.category))
                            .opacity(selectedChartAngle == nil ? 1.0 : (selectedItem?.category == item.category ? 1.0 : 0.3))
                        }
                        .chartLegend(.hidden)
                        // IMPORTANT: Sector selection mechanism
                        .chartAngleSelection(value: $selectedChartAngle)
                        .frame(height: 220)
                        
                        // 4. Center text (Info on hover)
                        VStack {
                            if let selected = selectedItem {
                                Text(selected.category)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                Text("\(selected.total, specifier: "%.0f") ₴")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(.primary)
                            } else {
                                // If nothing selected - show total amount
                                Text(L10n.get("Total"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(totalFiltered, specifier: "%.0f") ₴")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 5)
            
            #if os(macOS)
            Spacer()
            #else
            Divider()
            #endif
            
            // Savings
            VStack(alignment: .leading) {
                HStack {
                    Label(L10n.get("Savings"), systemImage: "safe.fill").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.get("Manage")) { manualAmount = 0; showSavingsManager = true }
                        .font(.caption).buttonStyle(.bordered)
                }
                HStack {
                    Text("\((totalAccumulatedSavings + totalSavings), specifier: "%.0f") ₴")
                        .font(.system(size: 24, weight: .bold, design: .monospaced)).foregroundStyle(.blue)
                    Spacer()
                    Text("≈ \((totalAccumulatedSavings + totalSavings) / exchangeRate, specifier: "%.0f") $")
                        .font(.body).foregroundStyle(.blue.opacity(0.8))
                }
                #if os(macOS)
                Text("\(L10n.get("Accumulated:")) \(totalAccumulatedSavings, specifier: "%.0f") ₴").font(.caption2).foregroundStyle(.secondary)
                Text("\(L10n.get("+ This month:")) \(totalSavings, specifier: "%.0f") ₴").font(.caption2).foregroundStyle(.green)
                #endif
            }
            .padding(10).background(Color.blue.opacity(0.1)).cornerRadius(12)
            
            Button(action: finishMonth) {
                HStack { Image(systemName: "checkmark.circle"); Text(L10n.get("Finish Month")) }
                    .frame(maxWidth: .infinity).padding(8)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
        }
    }
    
    // --- CHART SELECTION LOGIC ---
    
    func getSelectedCategory(data: [(category: String, total: Double)], total: Double) -> (category: String, total: Double)? {
        guard let angle = selectedChartAngle else { return nil }
        var currentSum = 0.0
        for item in data {
            let nextSum = currentSum + item.total
            if angle >= currentSum && angle <= nextSum { return item }
            currentSum = nextSum
        }
        return nil
    }
    
    // --- UI HELPERS ---
    
    var incomeHeader: some View {
        HStack {
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(.green)
            Text(L10n.get("Income")).font(.headline)
            Spacer()
            Text("\(totalIncomeUAH, specifier: "%.0f")").font(.system(.body, design: .monospaced))
        }
    }
    
    // New header with filters
    var expensesHeaderWithFilters: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "cart.fill").foregroundStyle(.orange)
                Text(L10n.get("Expenses List")).font(.headline)
                Spacer()
                Text("\(totalExpensesUAH, specifier: "%.0f")").font(.system(.body, design: .monospaced))
            }
            
            // Filter and sort panel
            HStack {
                // Sorting
                Menu {
                    Picker(L10n.get("Sorting"), selection: $sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.localizedName).tag(option)
                        }
                    }
                } label: {
                    Label(sortOption.localizedName, systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                // Status filter
                Picker("", selection: $filterStatus) {
                    ForEach(FilterStatus.allCases) { status in
                        Text(status.localizedName).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 200)
            }
        }
    }
    
    var savingsHeader: some View {
        HStack {
            Image(systemName: "safe.fill").foregroundStyle(.blue)
            Text(L10n.get("Savings Top-up")).font(.headline)
            Spacer()
            Text("\(totalSavings, specifier: "%.0f")").font(.system(.body, design: .monospaced))
        }
    }
    
    // INCOME Row
    func incomeRowView(item: IncomeItem) -> some View {
        HStack(spacing: 8) {
            TextField(L10n.get("Name"), text: Bindable(item).name)
            Divider()
            Picker("", selection: Bindable(item).isUSD) { Text("₴").tag(false); Text("$").tag(true) }
                .pickerStyle(.segmented).frame(width: 60)
            TextField("0", value: Bindable(item).amount, format: .number)
                .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 70)
            
            #if os(macOS)
            currencyPreview(amount: item.amount, isUSD: item.isUSD)
            #endif
        }
        .padding(.vertical, 2)
    }
    
    // INCOME Row for ExpenseItem (Savings)
    func incomeRowView(item: ExpenseItem) -> some View {
        HStack(spacing: 8) {
            TextField(L10n.get("Name"), text: Bindable(item).name)
            Divider()
            Picker("", selection: Bindable(item).isUSD) { Text("₴").tag(false); Text("$").tag(true) }
                .pickerStyle(.segmented).frame(width: 60)
            TextField("0", value: Bindable(item).amount, format: .number)
                .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 70)
            
            #if os(macOS)
            currencyPreview(amount: item.amount, isUSD: item.isUSD)
            #endif
        }
        .padding(.vertical, 2)
    }

    // EXPENSE ROW (UPDATED with Checkbox)
    func expenseRowView(item: ExpenseItem) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                // Payment checkbox
                Toggle(isOn: Bindable(item).isPaid) {
                    EmptyView()
                }
                .toggleStyle(CheckboxToggleStyle()) // Custom style or system style
                .frame(width: 20)
                
                Circle().fill(color(for: item.priority)).frame(width: 8, height: 8)
                
                TextField(L10n.get("Expense Name"), text: Bindable(item).name)
                    .frame(minWidth: 80)
                    .strikethrough(item.isPaid) // Strikethrough if paid
                    .foregroundStyle(item.isPaid ? .secondary : .primary)
                
                Picker(L10n.get("Category"), selection: Bindable(item).categoryName) {
                    ForEach(categories) { cat in Text(cat.name).tag(cat.name) }
                }
                .frame(width: 110).labelsHidden()
                #if os(iOS)
                .pickerStyle(.menu)
                #endif
                Divider()
                Picker("", selection: Bindable(item).isUSD) { Text("₴").tag(false); Text("$").tag(true) }
                    .pickerStyle(.segmented).frame(width: 60)
                TextField("0", value: Bindable(item).amount, format: .number)
                    .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 70)
                #if os(macOS)
                currencyPreview(amount: item.amount, isUSD: item.isUSD)
                #endif
            }
            HStack {
                Text("\(L10n.get("Priority"))").font(.caption2).foregroundStyle(.secondary)
                Picker(L10n.get("Priority"), selection: Bindable(item).priority) {
                    ForEach(Priority.allCases) { p in Text(priorityName(p)).tag(p) }
                }
                .pickerStyle(.segmented).controlSize(.mini).frame(maxWidth: 300)
                Spacer()
            }.padding(.leading, 38) // Increased padding due to checkbox
        }
        .padding(.vertical, 4)
        .opacity(item.isPaid ? 0.6 : 1.0) // Dimmer if paid
    }
    
    // Custom checkbox style
    struct CheckboxToggleStyle: ToggleStyle {
        func makeBody(configuration: Configuration) -> some View {
            Button {
                configuration.isOn.toggle()
            } label: {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(configuration.isOn ? .green : .gray)
            }
            .buttonStyle(.plain)
        }
    }
    
    func currencyPreview(amount: Double, isUSD: Bool) -> some View {
        Group {
            if isUSD {
                Text("≈ \(amount * exchangeRate, specifier: "%.0f") ₴").foregroundStyle(.secondary).font(.caption).frame(width: 60, alignment: .trailing)
            } else {
                Text("≈ \(amount / exchangeRate, specifier: "%.0f") $").foregroundStyle(.secondary).font(.caption).frame(width: 60, alignment: .trailing)
            }
        }
    }
    
    // --- HISTORY ---
    var historyView: some View {
        VStack {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Picker(L10n.get("View"), selection: $historyViewType) {
                        Text(L10n.get("List")).tag(0); Text(L10n.get("Charts")).tag(1)
                    }
                    .pickerStyle(.segmented)
                    
                    // NEW: Status Filter for History
                    HStack {
                        Text(L10n.get("Status:")).font(.caption).bold()
                        Spacer()
                        Picker("", selection: $filterStatus) {
                            ForEach(FilterStatus.allCases) { status in
                                Text(status.localizedName).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(width: 200)
                    }
                    
                    Text(L10n.get("Expense Filter:")).font(.caption).bold()
                    HStack(spacing: 15) {
                        Toggle(isOn: $filterEssential) { Text(L10n.get("Essential")).font(.caption).foregroundStyle(.red) }.toggleStyle(.button)
                        Toggle(isOn: $filterNeededNow) { Text(L10n.get("Needed")).font(.caption).foregroundStyle(.orange) }.toggleStyle(.button)
                        Toggle(isOn: $filterWant) { Text(L10n.get("Want")).font(.caption).foregroundStyle(.blue) }.toggleStyle(.button)
                    }.controlSize(.small)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.horizontal).padding(.top, 10)

            if history.isEmpty {
                ContentUnavailableView(L10n.get("Archive is empty"), systemImage: "archivebox")
            } else {
                List {
                    ForEach(historyByYear) { group in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedYears.contains(group.id) },
                                set: { isExpanding in if isExpanding { expandedYears.insert(group.id) } else { expandedYears.remove(group.id) } }
                            )
                        ) {
                            ForEach(group.records) { record in
                                if historyViewType == 0 { monthHistoryRow(record: record) } else { monthHistoryChart(record: record) }
                            }
                        } label: { Text(String(group.id)).font(.title2).bold().foregroundStyle(.blue) }
                    }
                }
                #if os(macOS)
                .overlay(alignment: .bottomTrailing) { Button(L10n.get("Clear")) { try? modelContext.delete(model: MonthHistory.self) }.padding() }
                #else
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L10n.get("Clear")) { try? modelContext.delete(model: MonthHistory.self) } } }
                #endif
            }
        }
    }
    
    func monthHistoryRow(record: MonthHistory) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedHistoryMonths.contains(record.id) },
                set: { isExpanding in if isExpanding { expandedHistoryMonths.insert(record.id) } else { expandedHistoryMonths.remove(record.id) } }
            )
        ) {
            if let expenses = record.expenses {
                let filteredExpenses = filterExpenses(expenses)
                if filteredExpenses.isEmpty && (!filterEssential || !filterNeededNow || !filterWant) {
                    Text(L10n.get("No expenses for selected filters")).font(.caption).italic().foregroundStyle(.secondary)
                } else {
                    let grouped = Dictionary(grouping: filteredExpenses, by: { $0.categoryName })
                    ForEach(grouped.keys.sorted(), id: \.self) { catName in
                        let catExpenses = grouped[catName]!
                        let catTotal = catExpenses.reduce(0) { $0 + toUAH(amount: $1.amount, isUSD: $1.isUSD) }
                        VStack(alignment: .leading) {
                            HStack { Text(catName).font(.subheadline).bold(); Spacer(); Text("\(catTotal, specifier: "%.0f") ₴").font(.subheadline).bold() }
                                .padding(.vertical, 2).background(Color.secondary.opacity(0.1))
                            ForEach(catExpenses) { exp in
                                HStack {
                                    Circle().fill(color(for: exp.priority)).frame(width: 6, height: 6)
                                    Text(exp.name).font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(exp.amount, specifier: "%.0f") \(exp.isUSD ? "$" : "₴")").font(.caption).foregroundStyle(.secondary)
                                }.padding(.leading, 10)
                            }
                        }.padding(.bottom, 4)
                    }
                }
            } else { Text(L10n.get("Details missing")).font(.caption) }
        } label: { historyHeaderLabel(record: record) }
    }
    
    func monthHistoryChart(record: MonthHistory) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedHistoryMonths.contains(record.id) },
                set: { isExpanding in if isExpanding { expandedHistoryMonths.insert(record.id) } else { expandedHistoryMonths.remove(record.id) } }
            )
        ) {
            if let expenses = record.expenses {
                let filteredExpenses = filterExpenses(expenses)
                if filteredExpenses.isEmpty {
                     Text(L10n.get("No data for chart")).font(.caption).foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text(L10n.get("By Category")).font(.caption).bold()
                            // Use the new interactive component to isolate state for each month's chart
                            HistoryCategoryChart(expenses: filteredExpenses, exchangeRate: exchangeRate)
                        }
                        Divider()
                        VStack(alignment: .leading) {
                            Text(L10n.get("By Priority")).font(.caption).bold()
                            Chart {
                                let grouped = Dictionary(grouping: filteredExpenses, by: { $0.priority })
                                ForEach(grouped.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { key in
                                    let value = grouped[key]!.reduce(0) { $0 + toUAH(amount: $1.amount, isUSD: $1.isUSD) }
                                    BarMark(x: .value(L10n.get("Type"), key.shortTitle), y: .value(L10n.get("Amount"), value))
                                        .foregroundStyle(color(for: key))
                                }
                            }.frame(height: 150)
                        }
                    }.padding()
                }
            }
        } label: { historyHeaderLabel(record: record) }
    }
    
    func historyHeaderLabel(record: MonthHistory) -> some View {
        HStack {
            Text(record.date.formatted(.dateTime.month(.wide))).bold().frame(width: 80, alignment: .leading)
            VStack(alignment: .leading) {
                Text("+\(record.totalIncomeUAH, specifier: "%.0f")").foregroundStyle(.green).font(.caption)
                Text("-\(record.totalExpenses, specifier: "%.0f")").foregroundStyle(.red).font(.caption)
            }
            Spacer()
            Text("\(L10n.get("Save:")) \(record.totalSaved, specifier: "%.0f")").font(.caption).foregroundStyle(.blue)
        }
    }
    
    func filterExpenses(_ expenses: [ExpenseItem]) -> [ExpenseItem] {
        return expenses.filter { exp in
            // Filter by Priority
            if exp.priority == .essential && !filterEssential { return false }
            if exp.priority == .neededNow && !filterNeededNow { return false }
            if exp.priority == .want && !filterWant { return false }
            
            // Filter by Status (NEW)
            switch filterStatus {
            case .all: break
            case .paid: if !exp.isPaid { return false }
            case .unpaid: if exp.isPaid { return false }
            }
            
            return true
        }
    }
    
    // --- MANAGERS ---
    var categoryManagerSheet: some View {
        NavigationStack {
            List {
                ForEach(categories) { cat in
                    HStack { Image(systemName: "tag.fill").foregroundStyle(.blue); TextField(L10n.get("Category Name"), text: Bindable(cat).name) }
                }.onDelete { idx in idx.forEach { modelContext.delete(categories[$0]) } }
                Button(L10n.get("Restore Default Categories")) {
                    let defaults = L10n.isUkrainian
                        ? ["Продукти", "Житло", "Транспорт", "Розваги", "Здоров'я", "Основні", "Інше"]
                        : ["Food", "Housing", "Transport", "Entertainment", "Health", "Essentials", "Other"]
                    for (index, name) in defaults.enumerated() { modelContext.insert(CategoryItem(name: name, order: index)) }
                }.foregroundStyle(.blue).padding(.top)
            }
            .navigationTitle(L10n.get("Manage Categories Title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) { Button(L10n.get("Done")) { showCategoryManager = false } }
                ToolbarItem(placement: .cancellationAction) { Button(L10n.get("+ Add")) { modelContext.insert(CategoryItem(name: L10n.get("New Category"), order: categories.count)) } }
            }
            #if os(macOS)
            .frame(width: 400, height: 500)
            #endif
        }
    }
    
    var savingsManagerSheet: some View {
        VStack(spacing: 20) {
            Text(L10n.get("Manage Savings")).font(.headline); Divider()
            HStack { Text(L10n.get("Balance:")); Spacer(); Text("\(totalAccumulatedSavings, specifier: "%.2f") ₴").bold() }.padding(.horizontal)
            GroupBox {
                HStack {
                    TextField(L10n.get("Amount"), value: $manualAmount, format: .number).textFieldStyle(.roundedBorder).font(.title3)
                    Picker("", selection: $manualIsUSD) { Text("₴").tag(false); Text("$").tag(true) }.pickerStyle(.segmented).frame(width: 80)
                }.padding(8)
            }
            HStack(spacing: 20) {
                Button(action: { totalAccumulatedSavings -= (manualIsUSD ? manualAmount * exchangeRate : manualAmount); showSavingsManager = false }) {
                    VStack { Image(systemName: "minus.circle.fill").font(.title); Text(L10n.get("Withdraw")) }.frame(maxWidth: .infinity).padding().background(Color.red.opacity(0.1)).foregroundStyle(.red).cornerRadius(10)
                }
                Button(action: { totalAccumulatedSavings += (manualIsUSD ? manualAmount * exchangeRate : manualAmount); showSavingsManager = false }) {
                    VStack { Image(systemName: "plus.circle.fill").font(.title); Text(L10n.get("Deposit")) }.frame(maxWidth: .infinity).padding().background(Color.green.opacity(0.1)).foregroundStyle(.green).cornerRadius(10)
                }
            }
            Spacer(); Button(L10n.get("Cancel")) { showSavingsManager = false }
        }.padding()
        #if os(macOS)
        .frame(width: 400, height: 400)
        #endif
    }
    
    func finishMonth() {
        let record = MonthHistory(totalIncomeUAH: totalIncomeUAH, totalExpenses: totalExpensesUAH, totalSaved: totalSavings, remaining: remainingBalance)
        var components = DateComponents(); components.year = selectedYear; components.month = selectedMonthIndex + 1; components.day = 1
        if let customDate = Calendar.current.date(from: components) { record.date = customDate }
        modelContext.insert(record)
        for expense in activeExpenses { expense.monthHistory = record }
        for saving in savingsGoals { saving.monthHistory = record }
        totalAccumulatedSavings += totalSavings
        try? modelContext.delete(model: IncomeItem.self)
    }
}

// --- NEW COMPONENT FOR HISTORY CHARTS ---
struct HistoryCategoryChart: View {
    let expenses: [ExpenseItem]
    let exchangeRate: Double
    
    @State private var selectedChartAngle: Double?
    
    var body: some View {
        // Prepare data
        let groupedData = Dictionary(grouping: expenses, by: { $0.categoryName })
            .map { (key, value) -> (category: String, total: Double) in
                // Calculate total in UAH
                let total = value.reduce(0) { sum, item in
                    sum + (item.isUSD ? item.amount * exchangeRate : item.amount)
                }
                return (key, total)
            }
            .sorted { $0.total > $1.total }
        
        let totalFiltered = groupedData.reduce(0) { $0 + $1.total }
        let selectedItem = getSelectedCategory(data: groupedData, total: totalFiltered)
        
        return ZStack {
            Chart(groupedData, id: \.category) { item in
                SectorMark(
                    angle: .value(L10n.get("Amount"), item.total),
                    innerRadius: .ratio(0.65), // Donut style
                    angularInset: 2.0
                )
                .cornerRadius(5)
                .foregroundStyle(by: .value(L10n.get("Category"), item.category))
                .opacity(selectedChartAngle == nil ? 1.0 : (selectedItem?.category == item.category ? 1.0 : 0.3))
            }
            .chartLegend(.hidden)
            .chartAngleSelection(value: $selectedChartAngle)
            .frame(height: 220)
            
            // Center info
            VStack {
                if let selected = selectedItem {
                    Text(selected.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("\(selected.total, specifier: "%.0f") ₴")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.primary)
                } else {
                    Text(L10n.get("Total"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(totalFiltered, specifier: "%.0f") ₴")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.primary)
                }
            }
        }
    }
    
    func getSelectedCategory(data: [(category: String, total: Double)], total: Double) -> (category: String, total: Double)? {
        guard let angle = selectedChartAngle else { return nil }
        var currentSum = 0.0
        for item in data {
            let nextSum = currentSum + item.total
            if angle >= currentSum && angle <= nextSum { return item }
            currentSum = nextSum
        }
        return nil
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [IncomeItem.self, CategoryItem.self, ExpenseItem.self, MonthHistory.self], inMemory: true)
}
