# KologShop - Ecommerce Website

A complete, responsive Amazon-like ecommerce platform built with Flutter. This module provides a full-featured online shopping experience with product browsing, cart management, checkout, and order tracking.

## 🌟 Features

### 🏠 Home Screen (`ecommerce_home.dart`)
- **Responsive Design**: Adapts to mobile, tablet, and desktop screens
- **Amazon-like Navigation**: Top navigation bar with logo and menu
- **Category Browsing**: Quick access to product categories
- **Featured Products**: Showcase special products
- **Today's Deals**: Highlight discounted items
- **Search Functionality**: Quick product search from home
- **Bottom Navigation** (Mobile): Easy navigation on smartphones

### 📦 Product Listing (`product_list_screen.dart`)
- **Advanced Filters**:
  - Price range slider
  - Stock availability filter
  - Category filter
- **Multiple Sorting Options**:
  - By name
  - Price: Low to High
  - Price: High to Low
- **Responsive Grid Layout**:
  - Desktop: 4 columns
  - Tablet: 3 columns
  - Mobile: 2 columns
- **Desktop Sidebar**: Persistent filter panel on large screens
- **Search Bar**: Real-time product search
- **Out of Stock Indicators**: Visual indicators for unavailable items

### 🛍️ Product Details (`product_detail_screen.dart`)
- **Full Product Information**
- **Image Display** with error handling
- **Price Mode Selection**: Retail vs Wholesale pricing
- **Quantity Selector**
- **Stock Information**
- **Add to Cart** functionality
- **Product Specifications**

### 📂 Categories (`category_screen.dart`)
- **Grid View** of all categories
- **Product Count** per category
- **Category Images** from first product
- **Responsive Layout**:
  - Desktop: 4 columns
  - Tablet: 3 columns
  - Mobile: 2 columns

### 🛒 Shopping Cart (`cart_screen.dart`)
- **Item Management**:
  - Update quantities
  - Remove items
  - Clear entire cart
- **Price Calculation**: Real-time total updates
- **Empty State** handling
- **Responsive Design**
- **Proceed to Checkout**

### 💳 Checkout (`checkout_screen.dart`)
- **Customer Information Form**:
  - Full name
  - Phone number
  - Delivery address
  - Additional notes
- **Payment Methods**:
  - Cash on Delivery
  - Mobile Money
  - Card Payment
- **Order Summary**
- **Form Validation**
- **Order Placement** to Firestore

### 📦 Orders (`orders_screen.dart`)
- **Order History** from Firestore
- **Order Filters**:
  - All orders
  - Pending
  - Processing
  - Delivered
  - Cancelled
- **Order Details**:
  - Customer information
  - Items ordered
  - Payment method
  - Status tracking
- **Status Indicators**: Color-coded status chips
- **Responsive Cards**
- **Order Detail Modal**: Full order information

### 👤 Account (`account_screen.dart`)
- **User Profile Display**
- **Account Options**:
  - Profile Information
  - Saved Addresses
  - Payment Methods
  - Notifications
  - Help & Support
  - About
- **Logout Functionality**
- **Responsive Layout**

## 📱 Responsive Design

The ecommerce website is fully responsive across all screen sizes:

### Mobile (< 600px)
- 2-column product grid
- Bottom navigation bar
- Collapsible filters
- Touch-optimized UI

### Tablet (600px - 1200px)
- 3-column product grid
- Enhanced spacing
- Larger touch targets

### Desktop (> 1200px)
- 4-column product grid
- Sidebar navigation
- Persistent filter panel
- Optimized for mouse interaction
- Maximum content width constraints

## 🎨 Design Features

### Color Scheme
- **Primary**: `#131921` (Amazon-inspired dark)
- **Secondary**: `#232F3E` (Dark gray)
- **Accent**: `#FF6B35` (Orange)
- **Error**: `#B12704` (Dark red)

### Amazon-inspired Elements
- Dark top navigation bar
- Category tiles
- Product cards with images
- Filter sidebar
- Status indicators
- Clean, professional layout

## 📊 Data Structure

### Products
Products are fetched from the `itemsreg` Firestore collection using the existing `ItemModel`:
- Product name, barcode, image
- Retail and wholesale pricing
- Stock levels
- Categories
- Warehouse information

### Orders
Orders are saved to `ecommerce_orders` collection:
```json
{
  "orderId": "auto-generated",
  "customerName": "string",
  "customerPhone": "string",
  "customerAddress": "string",
  "notes": "string",
  "paymentMethod": "cash|momo|card",
  "items": [
    {
      "productId": "string",
      "productName": "string",
      "quantity": number,
      "priceMode": "retail|wholesale",
      "price": number,
      "totalPrice": number
    }
  ],
  "totalQuantity": number,
  "totalAmount": number,
  "orderDate": timestamp,
  "status": "pending|processing|delivered|cancelled"
}
```

## 🚀 Usage

### Navigate to Ecommerce
```dart
Navigator.pushNamed(context, Routes.ecom);
```

### Or use direct navigation
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => EcommerceHome(),
  ),
);
```

## 📁 File Structure

```
lib/screens/ecommerce/
├── ecommerce_home.dart          # Main home page with navigation
├── product_list_screen.dart     # Product browsing with filters
├── product_detail_screen.dart   # Individual product view
├── category_screen.dart         # All categories grid
├── cart_screen.dart             # Shopping cart management
├── checkout_screen.dart         # Order checkout flow
├── orders_screen.dart           # Order history and tracking
├── account_screen.dart          # User account management
├── ecommerce.dart              # Barrel export file
└── README.md                   # This file

lib/models/
├── itemregmodel.dart           # Product model (existing)
└── cart_item_model.dart        # Cart item model

lib/providers/
└── cart_provider.dart          # Shopping cart state management
```

## 🔧 Setup & Dependencies

### Required Packages
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
  cloud_firestore: ^4.0.0
  firebase_auth: ^4.0.0
```

### Provider Setup (Already configured in main.dart)
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => CartProvider()),
    // ... other providers
  ],
  child: MyApp(),
)
```

## 🎯 Key Features Implementation

### Responsive Breakpoints
```dart
final isDesktop = constraints.maxWidth > 1200;
final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 1200;
final isMobile = constraints.maxWidth <= 600;
```

### Grid Columns
```dart
final crossAxisCount = isDesktop ? 4 : isTablet ? 3 : 2;
```

### Navigation
The home screen uses a bottom navigation bar on mobile and top navigation on desktop, switching between:
1. Home
2. Categories
3. Cart
4. Orders
5. Account

## 📈 Future Enhancements

- [ ] Product reviews and ratings
- [ ] Wishlist functionality
- [ ] Product recommendations
- [ ] Advanced search with autocomplete
- [ ] Image zoom and gallery
- [ ] Social sharing
- [ ] Discount codes/coupons
- [ ] Email notifications
- [ ] Push notifications
- [ ] Live chat support
- [ ] Multi-language support
- [ ] Currency selection
- [ ] Product comparisons
- [ ] Recently viewed products

## 🐛 Error Handling

- Network error handling with user-friendly messages
- Image loading fallbacks
- Empty state displays
- Form validation
- Transaction error handling

## 🔐 Security Considerations

- Firebase Authentication integration
- Route guards for protected pages
- Secure checkout process
- Input validation and sanitization

## 📱 Testing

Test the responsive design at different breakpoints:
- Mobile: 375px, 414px
- Tablet: 768px, 1024px
- Desktop: 1280px, 1920px

## 📞 Support

For issues or questions about the ecommerce module, refer to the main project documentation or contact the development team.

---

**Built with ❤️ using Flutter**
