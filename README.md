# MoneyPlanner 💰

**MoneyPlanner** is a modern, privacy-focused personal finance tracker built natively for **iOS** and **macOS**. Developed using **SwiftUI** and **SwiftData**, it helps you manage income, track expenses with priority tags, and achieve your savings goals through a clean and adaptive interface.

![Platform Support](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS-blue)
![Language](https://img.shields.io/badge/Language-Swift%205.9-orange)
![Framework](https://img.shields.io/badge/UI-SwiftUI-purple)

## ✨ Key Features

* **Adaptive Design:** Optimized layouts for both iPhone (Touch) and Mac (Keyboard/Mouse + Sidebar).
* **Smart Prioritization:** Tag every expense as **Essential**, **Needed**, or **Want** to analyze your spending habits.
* **Payment Tracking:** Simple checkboxes to mark bills as "Paid" or "Unpaid".
* **Savings Goal:** Dedicated "Piggy Bank" manager to track accumulated savings separately from monthly expenses.
* **Interactive Analytics:** Beautiful **Swift Charts** that visualize spending by category or priority with interactive selection.
* **Filtering & Sorting:** Powerful tools to sort expenses by date, amount, or payment status.
* **History Archive:** Automatically archives past months to keep your current planner clean.
* **Localization:** Built-in support for **English** and **Ukrainian** languages (auto-detects system language).

---

## 🛠 Prerequisites

To build and run this project, you need:

* **macOS:** Version 14.0 (Sonoma) or later.
* **Xcode:** Version 15.0 or later (required for SwiftData and `#Preview` macro support).
* **iOS Target:** iOS 17.0 or later (if deploying to iPhone).

---

## 🚀 Installation & Setup

### 1. Clone the Repository

Open your terminal and run the following command to download the project:

```bash
git clone [https://github.com/yourusername/MoneyPlanner.git](https://github.com/yourusername/MoneyPlanner.git)
cd MoneyPlanner
```

### 2. Open in Xcode

Double-click the `MoneyPlanner.xcodeproj` file to open the project.

### 3. Signing Setup (Important)

Before running on a real device:

1. Select the **MoneyPlanner** project icon in the left navigator.
2. Go to the **Signing & Capabilities** tab.
3. Under **Team**, select your Apple ID (Personal Team).
4. Ensure **Bundle Identifier** is unique (e.g., change `com.example.MoneyPlanner` to something unique like `com.yourname.MoneyPlanner`).

### 4. Build and Run

* **For Mac:** Select "My Mac" from the device list at the top and press `Cmd + R`.
* **For iPhone:** Connect your device, select it from the list, and press `Cmd + R`.

---

## 📖 Usage Guide

### The Planner Tab (Home)

This is your active monthly workspace.

* **Adding Items:** Use the **+ Add Income** or **+ Add Expense** buttons.
* **Expense Details:**
  * **Priority:** Choose between *Essential* (Red), *Needed* (Orange), or *Want* (Blue).
  * **Status:** Click the checkbox next to an expense to mark it as **Paid**.
* **Managing Categories:** Click the "Manage Categories" button at the top to add, remove, or restore default categories.
* **Filters:** Use the filter menu above the list to sort by "Most Expensive" or filter to see only "Unpaid" bills.

### The Right Panel (Dashboard)

* **Budget Overview:** See Income, Expenses, Savings, and Remaining Balance at a glance.
* **Interactive Chart:** Hover over (on Mac) or tap (on iOS) the donut chart to see exact amounts for specific categories.
* **Chart Filters:** Use the toggle buttons below the chart to exclude specific priorities (e.g., hide "Want" to see core survival budget).
* **Savings Manager:** Click "Manage" in the Savings section to Deposit or Withdraw funds from your long-term goal.

### The History Tab

* **Archives:** At the end of the month, click **"Finish Month"** in the Planner. This moves all active items into a read-only Archive in the History tab.
* **Analysis:** Expand any past month to review spending. Switch between **List View** and **Chart View** for visual analysis of past periods.

---

## 🏗 Architecture

* **SwiftUI:** Used for 100% of the user interface.
* **SwiftData:** Modern persistence framework for local data storage.
* **Charts:** Apple's native framework for data visualization.
* **MV Pattern:** The view logic is contained within `ContentView`, utilizing SwiftData's `@Query` macros for live data updates.

## 🤝 Contributing

Contributions are welcome! If you have ideas for improvements:

1. Fork the repository.
2. Create a feature branch.
3. Submit a Pull Request.

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
