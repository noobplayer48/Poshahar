# Poshahar Register

# Poshahar Register - Complete Project Specification for Flutter Developer

## 🎯 Project Overview

**Name**: Poshahar Register (Digital Mid-Day Meal Tracker)

**Target**: Single teacher in Rajasthan schools managing daily mid-day meal data

**Platform**: Flutter mobile app (offline-first)

**Purpose**: Replace manual paper registers with digital tracking for Rajasthan's "Poshahar Yojana"

---

## 🏛️ Government Scheme Understanding

### Core Concept:

The Rajasthan Mid-Day Meal Scheme provides:

1. **Raw grains**: गेहूँ (wheat) and चावल (rice) - delivered quarterly to schools
2. **Cooking cost**: ₹6 per student who actually eats - for purchasing vegetables, dal, spices, fuel, etc.

### Important Distinction:

- **We track**: गेहूँ/चावल consumption + ₹6 per eater for cooking costs
- **We DON'T track**: Individual vegetables, dal, spices (these come under the ₹6 cooking allowance)

---

## 📊 Data Structure & Fields

### Daily Entry Fields:

| Field (Hindi) | Field (English) | Type | Calculation | Description |
| --- | --- | --- | --- | --- |
| **दिनांक** | Date | Date | Manual | Entry date (defaults to today) |
| **कुल नामांकन** | Total Enrollment | Integer | Manual | Official student count |
| **उपस्थित छात्र** | Present Students | Integer | Manual | Students present today |
| **भोजन करने वाले छात्र** | Students Who Ate | Integer | Manual | Students who actually consumed food |
| **बनाये गये भोजन का विवरण** | Prepared Food Details | Dropdown | Manual | What dish was cooked today |
| **मुख्य अनाज** | Main Grain Used | Auto-select | Auto | गेहूँ or चावल (based on dish) |
| **अनाज की मात्रा (किलो)** | Grain Quantity Used | Decimal | Auto | Based on students × portion |
| **पोषाहार पकाने में व्यय राशि** | Cooking Expense | Integer | Auto | ₹6 × students who ate |
| **टिप्पणी** | Remarks | Text | Manual | Optional notes |

### Stock Management Fields:

| Field | Type | Description |
| --- | --- | --- |
| **गेहूँ स्टॉक** | Decimal | Current wheat stock in kg |
| **चावल स्टॉक** | Decimal | Current rice stock in kg |
| **गेहूँ प्राप्त** | Decimal | Wheat received (quarterly) |
| **चावल प्राप्त** | Decimal | Rice received (quarterly) |

---

## 🍽️ Menu System (Weekly Fixed Schedule)

### 6 Prepared Dishes (Fixed Weekly Rotation):

| Day | Dish (Hindi) | Dish (English) | Main Grain | Portion Size |
| --- | --- | --- | --- | --- |
| Monday | **दलिया** | Daliya/Porridge | गेहूँ | 150g/student |
| Tuesday | **चावल** | Rice | चावल | 100g/student |
| Wednesday | **रोटी-सब्जी** | Roti-Vegetable | गेहूँ | 150g/student |
| Thursday | **खिचड़ी** | Khichdi | चावल | 100g/student |
| Friday | **पूरी-सब्जी** | Puri-Vegetable | गेहूँ | 150g/student |
| Saturday | **चावल-दाल** | Rice-Dal | चावल | 100g/student |

### Auto-Logic:

- When date is selected → auto-suggest dish based on weekday
- When dish is selected → auto-determine main grain (गेहूँ/चावल)
- User can override the suggested dish if needed

---

## 💾 Data Storage Architecture

### Local Storage (SQLite):

```dart
// Daily Entries Table
CREATE TABLE daily_entries (
  id INTEGER PRIMARY KEY,
  date TEXT UNIQUE,
  total_enrollment INTEGER,
  present_students INTEGER,
  students_ate INTEGER,
  dish_prepared TEXT,
  main_grain TEXT,
  grain_used_kg REAL,
  cooking_expense INTEGER,
  remarks TEXT,
  created_at TIMESTAMP
);

// Stock Management Table
CREATE TABLE stock_management (
  id INTEGER PRIMARY KEY,
  gehu_stock REAL,
  chawal_stock REAL,
  last_updated TIMESTAMP
);

// Stock Transactions Table
CREATE TABLE stock_transactions (
  id INTEGER PRIMARY KEY,
  date TEXT,
  grain_type TEXT,
  quantity REAL,
  transaction_type TEXT, // 'received' or 'used'
  created_at TIMESTAMP
);

```

---

## 🔄 Business Logic & Calculations

### 1. Grain Usage Calculation:

```dart
double calculateGrainUsage(String dish, int studentsAte) {
  Map<String, double> portions = {
    'दलिया': 150.0,      // grams per student
    'रोटी-सब्जी': 150.0,
    'पूरी-सब्जी': 150.0,
    'चावल': 100.0,
    'खिचड़ी': 100.0,
    'चावल-दाल': 100.0,
  };

  double gramsPerStudent = portions[dish] ?? 0.0;
  return (studentsAte * gramsPerStudent) / 1000; // Convert to kg
}

```

### 2. Cooking Expense Calculation:

```dart
int calculateCookingExpense(int studentsAte) {
  return studentsAte * 6; // ₹6 per student fixed rate
}

```

### 3. Stock Deduction Logic:

```dart
void updateStock(String mainGrain, double quantityUsed) {
  if (mainGrain == 'गेहूँ') {
    currentStock.gehu -= quantityUsed;
  } else if (mainGrain == 'चावल') {
    currentStock.chawal -= quantityUsed;
  }
}

```

### 4. Stock Validation:

```dart
bool validateStockAvailability(String grain, double required) {
  if (grain == 'गेहूँ') {
    return currentStock.gehu >= required;
  } else if (grain == 'चावल') {
    return currentStock.chawal >= required;
  }
  return false;
}

```

---

## 🎨 UI/UX Requirements

### Screen Layout (Single Page):

1. **Header Section** (Compact):
    - Current stock display (गेहूँ: X kg, चावल: Y kg)
    - Add stock button (+) - opens modal
2. **Daily Entry Form**:
    - Date picker (defaults to today)
    - Student counts (3 fields)
    - Dish selection dropdown (6 options)
    - Auto-calculated fields (grain usage, expense) - read-only
    - Remarks (optional)
3. **Action Buttons**:
    - Save Entry (primary, large)
    - Export buttons (small, secondary)
4. **History List**:
    - Recent entries with edit capability
    - Summary cards showing key metrics

### Design Principles:

- **Hindi-first**: All labels in Devanagari
- **Large touch targets**: Minimum 48dp for mobile
- **Auto-calculations**: Real-time updates as user types
- **Error prevention**: Disable save if insufficient stock
- **Offline-first**: No internet dependency

---

## 📤 Export Functionality

### Excel Export Format:

```
| दिनांक | नामांकन | उपस्थित | भोजन करने वाले | बनाया गया भोजन | मुख्य अनाज | अनाज (किलो) | पकाने की राशि (₹) | टिप्पणी |

```

### PDF Export:

- A4 portrait layout
- School name header
- Month/year title
- Tabular data matching Excel format
- Summary footer (total students served, total expense)

---

## 🔄 Workflow & User Journey

### Daily Workflow:

1. **Open app** → See today's date pre-filled
2. **Check stock** → Visible at top, add if needed
3. **Enter student data** → Enrollment, present, ate
4. **Select dish** → Auto-suggests based on weekday
5. **Review calculations** → Auto-filled grain usage & expense
6. **Add remarks** → Optional notes
7. **Save entry** → Updates stock automatically
8. **View in history** → Entry appears in list below

### Monthly Workflow:

1. **Review month's data** → Scroll through history
2. **Export reports** → Excel for submission, PDF for records
3. **Add new stock** → When quarterly supplies arrive

### Stock Management:

1. **Receive supplies** → Use + button to add गेहूँ/चावल
2. **Monitor levels** → Visual indicators for low stock
3. **Track usage** → Automatic deduction per entry

---

## 🚦 Validation & Error Handling

### Input Validation:

- Students ate ≤ Students present ≤ Total enrollment
- Sufficient stock available for selected dish
- Date not in future
- All required fields filled

### Error Messages (Hindi):

- "स्टॉक कम है" (Insufficient stock)
- "उपस्थित छात्रों से अधिक नहीं खा सकते" (Can't exceed present students)
- "सभी आवश्यक फील्ड भरें" (Fill all required fields)

### Edge Cases:

- First-time app launch (initialize with zero stock)
- Editing past entries (recalculate stock from that date forward)
- Stock becomes negative (prevent save, show error)

---

## 📱 Technical Architecture for Flutter

### State Management:

- **Provider/Riverpod** for stock and entries management
- **Local state** for form inputs
- **Computed properties** for auto-calculations

### Database:

- **SQLite** with sqflite package
- **Migration support** for schema updates
- **Data models** with serialization

### File Operations:

- **excel package** for .xlsx generation
- **pdf package** for PDF reports
- **path_provider** for local storage

### Offline Support:

- **No network calls** required
- **Local storage only**
- **Export via file sharing**

---

## 🎯 Success Criteria

### For Teacher (End User):

- ✅ 5-minute daily data entry
- ✅ Zero math calculations needed
- ✅ Instant stock visibility
- ✅ One-click monthly reports
- ✅ Works without internet

### For Administration:

- ✅ Accurate government-format reports
- ✅ Audit trail of all entries
- ✅ Stock reconciliation capability
- ✅ Reduced manual errors

### Technical:

- ✅ <3 second app launch time
- ✅ Smooth 60fps UI performance
- ✅ Reliable offline storage
- ✅ Crash-free operation

- Preview in HTML (claude)
    
    ```html
    <!DOCTYPE html>
    <html lang="hi">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>पोषाहार रजिस्टर</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <style>
            @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+Devanagari:wght@300;400;500;600;700;800&display=swap');
            
            body {
                font-family: 'Noto Sans Devanagari', sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            }
            
            .glass-card {
                background: rgba(255, 255, 255, 0.95);
                backdrop-filter: blur(20px);
                border: 1px solid rgba(255, 255, 255, 0.2);
            }
            
            .input-field {
                transition: all 0.3s ease;
                border: 2px solid #e5e7eb;
                background: rgba(255, 255, 255, 0.9);
            }
            
            .input-field:focus {
                border-color: #3b82f6;
                box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
                transform: translateY(-1px);
            }
            
            .calculated-field {
                background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
                border: 2px solid #cbd5e1;
            }
            
            .save-button {
                background: linear-gradient(135deg, #10b981 0%, #059669 100%);
                transition: all 0.3s ease;
                box-shadow: 0 4px 15px rgba(16, 185, 129, 0.3);
            }
            
            .save-button:hover:not(:disabled) {
                transform: translateY(-2px);
                box-shadow: 0 8px 25px rgba(16, 185, 129, 0.4);
            }
            
            .save-button:disabled {
                background: #9ca3af;
                transform: none;
                box-shadow: none;
            }
            
            .export-btn {
                transition: all 0.3s ease;
                position: relative;
                overflow: hidden;
            }
            
            .export-btn:hover {
                transform: translateY(-1px);
            }
            
            .entry-card {
                transition: all 0.3s ease;
                background: rgba(255, 255, 255, 0.8);
                backdrop-filter: blur(10px);
                border: 1px solid rgba(255, 255, 255, 0.3);
            }
            
            .entry-card:hover {
                transform: translateY(-2px);
                box-shadow: 0 8px 25px rgba(0, 0, 0, 0.1);
            }
            
            .floating-label {
                position: relative;
            }
            
            .floating-label input,
            .floating-label select,
            .floating-label textarea {
                padding-top: 1.5rem;
            }
            
            .floating-label label {
                position: absolute;
                left: 1rem;
                top: 0.5rem;
                font-size: 0.75rem;
                font-weight: 500;
                color: #6b7280;
                pointer-events: none;
                transition: all 0.3s ease;
            }
            
            .error-shake {
                animation: shake 0.5s ease-in-out;
            }
            
            @keyframes shake {
                0%, 100% { transform: translateX(0); }
                25% { transform: translateX(-5px); }
                75% { transform: translateX(5px); }
            }
            
            .pulse-glow {
                animation: pulse-glow 2s infinite;
            }
            
            @keyframes pulse-glow {
                0%, 100% { box-shadow: 0 0 5px rgba(59, 130, 246, 0.5); }
                50% { box-shadow: 0 0 20px rgba(59, 130, 246, 0.8); }
            }
            
            .stats-card {
                background: linear-gradient(135deg, rgba(255,255,255,0.9) 0%, rgba(255,255,255,0.7) 100%);
                backdrop-filter: blur(15px);
                border: 1px solid rgba(255, 255, 255, 0.3);
            }
            
            .add-stock-btn {
                position: fixed;
                top: 20px;
                right: 20px;
                z-index: 50;
                background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
                box-shadow: 0 4px 15px rgba(245, 158, 11, 0.3);
            }
            
            .add-stock-btn:hover {
                transform: scale(1.1);
                box-shadow: 0 6px 20px rgba(245, 158, 11, 0.4);
            }
            
            .stock-modal {
                backdrop-filter: blur(10px);
                background: rgba(0, 0, 0, 0.5);
            }
        </style>
    </head>
    <body class="min-h-screen">
        <div class="max-w-md mx-auto min-h-screen relative">
            <!-- Add Stock Button (Top Right) -->
            <button id="addStockBtn" class="add-stock-btn w-12 h-12 text-white rounded-full flex items-center justify-center font-bold text-xl transition-all duration-300">
                <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z"/>
                </svg>
            </button>
    
            <!-- Stock Modal -->
            <div id="stockModal" class="fixed inset-0 stock-modal hidden z-40">
                <div class="flex items-center justify-center min-h-screen p-4">
                    <div class="glass-card rounded-2xl p-6 w-full max-w-sm">
                        <h3 class="text-lg font-bold text-gray-800 mb-4 text-center">स्टॉक जोड़ें</h3>
                        
                        <div class="space-y-4">
                            <div class="floating-label">
                                <label>गेहूँ (किलो)</label>
                                <input type="number" id="modalGehuReceived" step="0.01" class="w-full p-4 rounded-xl input-field text-lg" placeholder="0.00">
                            </div>
                            
                            <div class="floating-label">
                                <label>चावल (किलो)</label>
                                <input type="number" id="modalChawalReceived" step="0.01" class="w-full p-4 rounded-xl input-field text-lg" placeholder="0.00">
                            </div>
                            
                            <div class="grid grid-cols-2 gap-3 mt-6">
                                <button id="cancelStockBtn" class="p-3 bg-gray-500 text-white rounded-xl font-medium hover:bg-gray-600">
                                    रद्द करें
                                </button>
                                <button id="saveStockBtn" class="p-3 bg-blue-600 text-white rounded-xl font-medium hover:bg-blue-700">
                                    जोड़ें
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
    
            <!-- Main Content -->
            <div class="p-4 pt-20 space-y-6">
                <!-- Current Stock Display -->
                <div class="glass-card rounded-2xl p-4 shadow-lg">
                    <h2 class="text-sm font-semibold text-gray-600 mb-3 text-center">वर्तमान स्टॉक</h2>
                    <div class="grid grid-cols-2 gap-4">
                        <div class="stats-card rounded-xl p-3 text-center">
                            <div class="text-lg font-bold text-amber-600" id="gehuStock">--</div>
                            <div class="text-xs text-gray-600">गेहूँ (किलो)</div>
                        </div>
                        <div class="stats-card rounded-xl p-3 text-center">
                            <div class="text-lg font-bold text-green-600" id="chawalStock">--</div>
                            <div class="text-xs text-gray-600">चावल (किलो)</div>
                        </div>
                    </div>
                </div>
    
                <!-- Daily Entry Form -->
                <div class="glass-card rounded-2xl p-6 shadow-lg">
                    <h2 class="text-lg font-semibold text-gray-800 mb-4 flex items-center">
                        <div class="w-2 h-2 bg-blue-500 rounded-full mr-3"></div>
                        आज की प्रविष्टि
                    </h2>
                    
                    <div class="space-y-4">
                        <div class="floating-label">
                            <label>दिनांक</label>
                            <input type="date" id="date" class="w-full p-4 rounded-xl input-field text-lg font-medium">
                        </div>
    
                        <div class="floating-label">
                            <label>कुल नामांकन</label>
                            <input type="number" id="enrolled" class="w-full p-4 rounded-xl input-field text-lg font-medium" placeholder="30">
                        </div>
    
                        <div class="floating-label">
                            <label>उपस्थित कुल छात्र</label>
                            <input type="number" id="present" class="w-full p-4 rounded-xl input-field text-lg font-medium" placeholder="28">
                        </div>
    
                        <div class="floating-label">
                            <label>भोजन करने वाले छात्र</label>
                            <input type="number" id="eaters" class="w-full p-4 rounded-xl input-field text-lg font-bold text-blue-600" placeholder="25">
                        </div>
    
                        <div class="floating-label">
                            <label>आज का मेन्यू</label>
                            <select id="menu" class="w-full p-4 rounded-xl input-field text-lg font-medium">
                                <option value="">मेन्यू चुनें</option>
                                <option value="गेहूँ">🌾 गेहूँ (150g/छात्र)</option>
                                <option value="चावल">🍚 चावल (100g/छात्र)</option>
                            </select>
                        </div>
                    </div>
                </div>
    
                <!-- Auto Calculations Display -->
                <div class="glass-card rounded-2xl p-6 shadow-lg">
                    <h2 class="text-lg font-semibold text-gray-800 mb-4 flex items-center">
                        <div class="w-2 h-2 bg-purple-500 rounded-full mr-3"></div>
                        स्वचालित गणना
                    </h2>
                    
                    <div class="grid grid-cols-1 gap-4">
                        <div class="floating-label">
                            <label>खाद्यान्न खर्च (किलो)</label>
                            <input type="number" id="used" step="0.01" class="w-full p-4 rounded-xl calculated-field text-lg font-bold text-red-600" readonly>
                        </div>
    
                        <div class="floating-label">
                            <label>शेष खाद्यान्न (किलो)</label>
                            <input type="number" id="remaining" step="0.01" class="w-full p-4 rounded-xl calculated-field text-lg font-bold text-green-600" readonly>
                        </div>
    
                        <div class="floating-label">
                            <label>खर्च (₹)</label>
                            <input type="number" id="cost" step="1" class="w-full p-4 rounded-xl calculated-field text-lg font-bold text-blue-600" readonly>
                        </div>
                    </div>
                </div>
    
                <!-- Remarks Section -->
                <div class="glass-card rounded-2xl p-6 shadow-lg">
                    <div class="floating-label">
                        <label>टिप्पणी (वैकल्पिक)</label>
                        <textarea id="remarks" rows="3" class="w-full p-4 rounded-xl input-field resize-none" placeholder="कोई विशेष बात या नोट्स..."></textarea>
                    </div>
                </div>
    
                <!-- Error Message -->
                <div id="errorMessage" class="glass-card rounded-2xl p-4 bg-red-50 border-2 border-red-200 hidden error-shake">
                    <div class="flex items-center">
                        <div class="w-6 h-6 bg-red-500 rounded-full flex items-center justify-center mr-3">
                            <svg class="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"/>
                            </svg>
                        </div>
                        <p class="text-red-700 font-medium">उपलब्ध मात्रा से अधिक उपयोग नहीं कर सकते।</p>
                    </div>
                </div>
    
                <!-- Save Button -->
                <button id="saveBtn" class="w-full p-5 save-button text-white rounded-2xl font-bold text-xl shadow-lg disabled:cursor-not-allowed">
                    <span class="flex items-center justify-center">
                        <svg class="w-6 h-6 mr-3" fill="currentColor" viewBox="0 0 20 20">
                            <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"/>
                        </svg>
                        सेव करें
                    </span>
                </button>
    
                <!-- Export Buttons (Smaller) -->
                <div class="grid grid-cols-2 gap-3">
                    <button class="export-btn p-2 bg-gradient-to-br from-green-500 to-green-600 text-white rounded-lg font-medium text-sm shadow-md">
                        📊 Excel निर्यात
                    </button>
                    <button class="export-btn p-2 bg-gradient-to-br from-red-500 to-red-600 text-white rounded-lg font-medium text-sm shadow-md">
                        📄 PDF निर्यात
                    </button>
                </div>
    
                <!-- Entries List -->
                <div class="glass-card rounded-2xl p-6 shadow-lg">
                    <h2 class="text-xl font-bold text-gray-800 mb-6 flex items-center">
                        <div class="w-3 h-3 bg-indigo-500 rounded-full mr-3"></div>
                        पिछली प्रविष्टियाँ
                    </h2>
                    <div id="entriesList" class="space-y-4">
                        <!-- Entries will be populated here -->
                    </div>
                </div>
    
                <!-- Bottom Spacing -->
                <div class="h-8"></div>
            </div>
        </div>
    
        <script>
            // Menu allotments in grams per student (only Gehu and Chawal)
            const menuAllotments = {
                'गेहूँ': 150,
                'चावल': 100
            };
    
            // Weekly menu (0 = Sunday, 1 = Monday, etc.) - only Gehu and Chawal
            const weeklyMenu = {
                1: 'गेहूँ',
                2: 'चावल',
                3: 'गेहूँ',
                4: 'चावल',
                5: 'गेहूँ',
                6: 'चावल'
            };
    
            let entries = [];
            let editingIndex = -1;
            let currentStock = { gehu: 0, chawal: 0 };
    
            // Initialize the app
            document.addEventListener('DOMContentLoaded', function() {
                loadData();
                setTodayDate();
                setWeeklyMenu();
                setupEventListeners();
                renderEntries();
                updateStockDisplay();
            });
    
            function loadData() {
                const savedData = localStorage.getItem('poshaharEntries');
                const savedStock = localStorage.getItem('poshaharStock');
                
                if (savedData) {
                    entries = JSON.parse(savedData);
                } else {
                    // Add sample data for demonstration
                    entries = [
                        {
                            date: '2025-01-30',
                            enrolled: 30,
                            present: 28,
                            eaters: 25,
                            menu: 'गेहूँ',
                            used: 3.75,
                            cost: 150,
                            remarks: ''
                        },
                        {
                            date: '2025-01-31',
                            enrolled: 30,
                            present: 29,
                            eaters: 27,
                            menu: 'चावल',
                            used: 2.70,
                            cost: 162,
                            remarks: ''
                        }
                    ];
                    saveData();
                }
                
                if (savedStock) {
                    currentStock = JSON.parse(savedStock);
                } else {
                    currentStock = { gehu: 100.0, chawal: 50.0 };
                    saveStock();
                }
            }
    
            function saveData() {
                localStorage.setItem('poshaharEntries', JSON.stringify(entries));
            }
    
            function saveStock() {
                localStorage.setItem('poshaharStock', JSON.stringify(currentStock));
            }
    
            function updateStockDisplay() {
                document.getElementById('gehuStock').textContent = currentStock.gehu.toFixed(1);
                document.getElementById('chawalStock').textContent = currentStock.chawal.toFixed(1);
            }
    
            function setTodayDate() {
                const today = new Date().toISOString().split('T')[0];
                document.getElementById('date').value = today;
            }
    
            function setWeeklyMenu() {
                const dateInput = document.getElementById('date');
                const menuSelect = document.getElementById('menu');
                
                const date = new Date(dateInput.value);
                const dayOfWeek = date.getDay();
                
                if (weeklyMenu[dayOfWeek]) {
                    menuSelect.value = weeklyMenu[dayOfWeek];
                }
            }
    
            function calculate() {
                const eaters = parseFloat(document.getElementById('eaters').value) || 0;
                const menu = document.getElementById('menu').value;
                
                // Calculate used amount
                let used = 0;
                if (menu && menuAllotments[menu]) {
                    used = (eaters * menuAllotments[menu]) / 1000; // Convert grams to kg
                }
                
                // Calculate remaining stock
                let remaining = 0;
                if (menu === 'गेहूँ') {
                    remaining = currentStock.gehu - used;
                } else if (menu === 'चावल') {
                    remaining = currentStock.chawal - used;
                }
                
                // Calculate cost (₹6 per student per day)
                const cost = eaters * 6;
                
                // Update fields with animation
                const usedField = document.getElementById('used');
                const remainingField = document.getElementById('remaining');
                const costField = document.getElementById('cost');
                
                usedField.value = used.toFixed(2);
                remainingField.value = remaining.toFixed(2);
                costField.value = cost.toFixed(0);
                
                // Add pulse effect to calculated fields
                [usedField, remainingField, costField].forEach(field => {
                    field.classList.add('pulse-glow');
                    setTimeout(() => field.classList.remove('pulse-glow'), 1000);
                });
                
                // Check for errors
                const errorDiv = document.getElementById('errorMessage');
                const saveBtn = document.getElementById('saveBtn');
                
                if (remaining < 0) {
                    errorDiv.classList.remove('hidden');
                    errorDiv.classList.add('error-shake');
                    saveBtn.disabled = true;
                    setTimeout(() => errorDiv.classList.remove('error-shake'), 500);
                } else {
                    errorDiv.classList.add('hidden');
                    saveBtn.disabled = false;
                }
            }
    
            function setupEventListeners() {
                // Auto-calculation triggers
                ['eaters', 'menu'].forEach(id => {
                    const element = document.getElementById(id);
                    element.addEventListener('input', calculate);
                    element.addEventListener('change', calculate);
                    
                    // Add focus animations
                    element.addEventListener('focus', function() {
                        this.parentElement.classList.add('pulse-glow');
                    });
                    
                    element.addEventListener('blur', function() {
                        this.parentElement.classList.remove('pulse-glow');
                    });
                });
                
                // Date change handler
                document.getElementById('date').addEventListener('change', function() {
                    setWeeklyMenu();
                    calculate();
                });
                
                // Save button
                document.getElementById('saveBtn').addEventListener('click', saveEntry);
                
                // Form validation
                ['date', 'enrolled', 'present', 'eaters', 'menu'].forEach(id => {
                    document.getElementById(id).addEventListener('input', validateForm);
                });
                
                // Stock modal handlers
                document.getElementById('addStockBtn').addEventListener('click', () => {
                    document.getElementById('stockModal').classList.remove('hidden');
                });
                
                document.getElementById('cancelStockBtn').addEventListener('click', () => {
                    document.getElementById('stockModal').classList.add('hidden');
                    document.getElementById('modalGehuReceived').value = '';
                    document.getElementById('modalChawalReceived').value = '';
                });
                
                document.getElementById('saveStockBtn').addEventListener('click', addStock);
            }
    
            function addStock() {
                const gehuReceived = parseFloat(document.getElementById('modalGehuReceived').value) || 0;
                const chawalReceived = parseFloat(document.getElementById('modalChawalReceived').value) || 0;
                
                if (gehuReceived > 0 || chawalReceived > 0) {
                    currentStock.gehu += gehuReceived;
                    currentStock.chawal += chawalReceived;
                    
                    saveStock();
                    updateStockDisplay();
                    
                    // Close modal and clear inputs
                    document.getElementById('stockModal').classList.add('hidden');
                    document.getElementById('modalGehuReceived').value = '';
                    document.getElementById('modalChawalReceived').value = '';
                    
                    // Recalculate current form
                    calculate();
                }
            }
    
            function validateForm() {
                const required = ['date', 'enrolled', 'present', 'eaters', 'menu'];
                const saveBtn = document.getElementById('saveBtn');
                
                const allFilled = required.every(id => {
                    const value = document.getElementById(id).value;
                    return value && value.trim() !== '';
                });
                
                const remaining = parseFloat(document.getElementById('remaining').value) || 0;
                
                saveBtn.disabled = !allFilled || remaining < 0;
            }
    
            function saveEntry() {
                const saveBtn = document.getElementById('saveBtn');
                const menu = document.getElementById('menu').value;
                const used = parseFloat(document.getElementById('used').value) || 0;
                
                // Add loading state
                const originalText = saveBtn.innerHTML;
                saveBtn.innerHTML = `
                    <span class="flex items-center justify-center">
                        <svg class="animate-spin w-6 h-6 mr-3" fill="none" viewBox="0 0 24 24">
                            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                        </svg>
                        सेव हो रहा है...
                    </span>
                `;
                saveBtn.disabled = true;
                
                setTimeout(() => {
                    const entry = {
                        date: document.getElementById('date').value,
                        enrolled: parseInt(document.getElementById('enrolled').value) || 0,
                        present: parseInt(document.getElementById('present').value) || 0,
                        eaters: parseInt(document.getElementById('eaters').value) || 0,
                        menu: menu,
                        used: used,
                        cost: parseFloat(document.getElementById('cost').value) || 0,
                        remarks: document.getElementById('remarks').value.trim()
                    };
                    
                    // Update stock
                    if (menu === 'गेहूँ') {
                        currentStock.gehu -= used;
                    } else if (menu === 'चावल') {
                        currentStock.chawal -= used;
                    }
                    
                    if (editingIndex >= 0) {
                        entries[editingIndex] = entry;
                        editingIndex = -1;
                    } else {
                        // Check if entry already exists for this date
                        const existingIndex = entries.findIndex(e => e.date === entry.date);
                        if (existingIndex >= 0) {
                            entries[existingIndex] = entry;
                        } else {
                            entries.push(entry);
                        }
                    }
                    
                    // Sort entries by date
                    entries.sort((a, b) => new Date(a.date) - new Date(b.date));
                    
                    saveData();
                    saveStock();
                    updateStockDisplay();
                    renderEntries();
                    clearForm();
                    
                    // Success feedback
                    saveBtn.innerHTML = `
                        <span class="flex items-center justify-center">
                            <svg class="w-6 h-6 mr-3" fill="currentColor" viewBox="0 0 20 20">
                                <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"/>
                            </svg>
                            सफलतापूर्वक सेव हुआ!
                        </span>
                    `;
                    saveBtn.classList.add('success-button');
                    
                    setTimeout(() => {
                        saveBtn.innerHTML = originalText;
                        saveBtn.classList.remove('success-button');
                        saveBtn.disabled = false;
                    }, 2000);
                }, 1000);
            }
    
            function clearForm() {
                document.getElementById('enrolled').value = '';
                document.getElementById('present').value = '';
                document.getElementById('eaters').value = '';
                document.getElementById('remarks').value = '';
                
                setTodayDate();
                setWeeklyMenu();
                calculate();
            }
    
            function editEntry(index) {
                const entry = entries[index];
                editingIndex = index;
                
                document.getElementById('date').value = entry.date;
                document.getElementById('enrolled').value = entry.enrolled;
                document.getElementById('present').value = entry.present;
                document.getElementById('eaters').value = entry.eaters;
                document.getElementById('menu').value = entry.menu;
                document.getElementById('used').value = entry.used.toFixed(2);
                document.getElementById('cost').value = entry.cost.toFixed(0);
                document.getElementById('remarks').value = entry.remarks;
                
                // Scroll to top with smooth animation
                window.scrollTo({ top: 0, behavior: 'smooth' });
            }
    
            function renderEntries() {
                const container = document.getElementById('entriesList');
                
                if (entries.length === 0) {
                    container.innerHTML = `
                        <div class="text-center py-8">
                            <div class="w-16 h-16 bg-gray-200 rounded-full flex items-center justify-center mx-auto mb-4">
                                <svg class="w-8 h-8 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z"/>
                                </svg>
                            </div>
                            <p class="text-gray-500 font-medium">अभी तक कोई प्रविष्टि नहीं है</p>
                            <p class="text-sm text-gray-400 mt-1">पहली प्रविष्टि जोड़ने के लिए ऊपर फॉर्म भरें</p>
                        </div>
                    `;
                    return;
                }
                
                // Sort entries by date (most recent first for display)
                const sortedEntries = [...entries].sort((a, b) => new Date(b.date) - new Date(a.date));
                
                container.innerHTML = sortedEntries.map((entry, index) => {
                    const originalIndex = entries.findIndex(e => e.date === entry.date);
                    const date = new Date(entry.date).toLocaleDateString('hi-IN', {
                        weekday: 'short',
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric'
                    });
                    
                    const menuEmoji = {
                        'गेहूँ': '🌾',
                        'चावल': '🍚'
                    };
                    
                    const isToday = entry.date === new Date().toISOString().split('T')[0];
                    
                    return `
                        <div class="entry-card rounded-2xl p-5 shadow-lg relative ${isToday ? 'ring-2 ring-blue-400 ring-opacity-50' : ''}">
                            ${isToday ? '<div class="absolute -top-2 -right-2 bg-blue-500 text-white text-xs px-2 py-1 rounded-full font-bold">आज</div>' : ''}
                            
                            <div class="flex justify-between items-start mb-4">
                                <div class="flex-1">
                                    <div class="flex items-center mb-2">
                                        <div class="text-2xl mr-3">${menuEmoji[entry.menu] || '🍽️'}</div>
                                        <div>
                                            <p class="font-bold text-gray-800 text-lg">${date}</p>
                                            <p class="text-sm text-gray-600 font-medium">${entry.menu}</p>
                                        </div>
                                    </div>
                                    
                                    <div class="flex items-center text-sm text-gray-600 mb-2">
                                        <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                                            <path d="M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v3h8v-3z"/>
                                        </svg>
                                        <span class="font-medium text-blue-600">${entry.eaters}</span>
                                        <span class="mx-1">छात्रों ने खाना खाया</span>
                                        <span class="text-gray-400">/ ${entry.present} उपस्थित</span>
                                    </div>
                                </div>
                                
                                <button onclick="editEntry(${originalIndex})" class="bg-gradient-to-br from-blue-500 to-blue-600 text-white px-4 py-2 rounded-xl text-sm font-bold shadow-lg hover:shadow-xl transition-all duration-300 hover:-translate-y-1">
                                    <svg class="w-4 h-4 inline mr-1" fill="currentColor" viewBox="0 0 20 20">
                                        <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z"/>
                                    </svg>
                                    संपादित करें
                                </button>
                            </div>
                            
                            <div class="grid grid-cols-3 gap-4 mb-3">
                                <div class="bg-gradient-to-br from-red-50 to-red-100 rounded-xl p-3 text-center">
                                    <div class="text-lg font-bold text-red-600">${entry.used.toFixed(1)}</div>
                                    <div class="text-xs text-red-500 font-medium">उपयोग (किलो)</div>
                                </div>
                                <div class="bg-gradient-to-br from-blue-50 to-blue-100 rounded-xl p-3 text-center">
                                    <div class="text-lg font-bold text-blue-600">₹${entry.cost}</div>
                                    <div class="text-xs text-blue-500 font-medium">कुल खर्च</div>
                                </div>
                                <div class="bg-gradient-to-br from-purple-50 to-purple-100 rounded-xl p-3 text-center">
                                    <div class="text-lg font-bold text-purple-600">${entry.enrolled}</div>
                                    <div class="text-xs text-purple-500 font-medium">नामांकन</div>
                                </div>
                            </div>
                            
                            ${entry.remarks ? `
                                <div class="bg-gray-50 rounded-lg p-3 border-l-4 border-purple-400">
                                    <div class="flex items-start">
                                        <svg class="w-4 h-4 text-purple-500 mr-2 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                                            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"/>
                                        </svg>
                                        <p class="text-sm text-gray-700 italic">"${entry.remarks}"</p>
                                    </div>
                                </div>
                            ` : ''}
                        </div>
                    `;
                }).join('');
            }
    
            // Initial calculations
            calculate();
            validateForm();
        </script>
    </body>
    </html>
    ```