enum BusinessCategory { categoryA, categoryB, categoryC }

class BusinessSubcategory {
  final String name;
  final String description;
  final BusinessCategory category;
  const BusinessSubcategory({
    required this.name,
    required this.description,
    required this.category,
  });
}

class BusinessCategories {
  static const List<BusinessSubcategory> subcategories = [
    // Category A1 – High-Risk Industrial
    BusinessSubcategory(
      name: 'LPG bottling plants',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Fuel depots & tank farms',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Oil processing facilities',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Industrial gas plants',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Power generation plants',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Large factories with boilers/pressure systems',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Mining (large & small scale)',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Quarries & stone crushing plants',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Sand winning companies',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Cement & steel factories',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Chemical factories',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Paint factories',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Pharmaceutical factories',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Waste treatment plants',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Hazardous waste facilities',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Industrial incinerators',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Large water treatment plants',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Heavy engineering workshops',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Large beverage factories',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Mega plastics factories',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Large agro-processing plants',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'High‑capacity cold storage facilities',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'High‑capacity logistics yards',
      description: 'A1 – High-Risk Industrial',
      category: BusinessCategory.categoryA,
    ),
    // Category A2 – High‑Revenue Institutions
    BusinessSubcategory(
      name: 'Banks & financial institutions (all branches)',
      description: 'A2 – High‑Revenue Institutions',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Insurance headquarters',
      description: 'A2 – High‑Revenue Institutions',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Telecommunications headquarters (MTN, Vodafone, AirtelTigo)',
      description: 'A2 – High‑Revenue Institutions',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Large supermarkets/retail chains (Melcom, Shoprite, Palace)',
      description: 'A2 – High‑Revenue Institutions',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Major malls and retail complexes',
      description: 'A2 – High‑Revenue Institutions',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Large hospitals',
      description: 'A2 – High‑Revenue Institutions',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Universities & tertiary institutions',
      description: 'A2 – High‑Revenue Institutions',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Large hotels (4–5 star)',
      description: 'A2 – High‑Revenue Institutions',
      category: BusinessCategory.categoryA,
    ),
    BusinessSubcategory(
      name: 'Corporate office towers',
      description: 'A2 – High‑Revenue Institutions',
      category: BusinessCategory.categoryA,
    ),
    // Category B – Medium Risk & Medium Revenue
    BusinessSubcategory(
      name: 'Medium manufacturing factories',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Medium agro‑processing plants',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Rice/maize/cassava mills',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Shea & palm oil processors',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Fruit juice factories',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Poultry feed mills',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Livestock processing units',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Construction firms with machinery',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Block factories',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Concrete batching plants',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Asphalt plants',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Warehouses using forklifts',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Medium cold stores',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Distribution centres',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Industrial printing presses',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Furniture factories',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Wood processing/sawmills',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Metal fabrication workshops (medium)',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Aluminium production workshops',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Medium industrial bakeries',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Textile & garment factories',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Shoe & leather factories',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Hotels with industrial kitchens',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Restaurants with industrial kitchens',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Catering companies',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Hospitals & clinics (medium)',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Schools with technical workshops',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Vocational training centres',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Prisons with industrial units',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Industrial laundries',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Vehicle assembly workshops',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    BusinessSubcategory(
      name: 'Electronics assembly centres',
      description: 'Medium Risk & Medium Revenue',
      category: BusinessCategory.categoryB,
    ),
    // Category C – Low Risk & Low Revenue
    BusinessSubcategory(
      name: 'Small bakeries',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Welding shops (small scale)',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Carpentry workshops',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Small sawmills',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Auto mechanic shops with lifts',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Spray painting shops',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Tyre vulcanizing shops',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Small metal workshops',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Small printing centres',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Small block‑making units',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Small garment/tailoring shops',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Household furniture workshops',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Small packaging facilities',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Micro agro‑processing units',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Micro cosmetic/soap units',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Ice block producers',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Micro sachet water producers',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Small cold rooms',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Small shops using simple machines',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Small offices',
      description: 'Low Risk & Low Revenue',
      category: BusinessCategory.categoryC,
    ),
    // Offices Under Category C
    BusinessSubcategory(
      name: 'Government administrative offices',
      description: 'Offices Under Category C',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'District assembly offices',
      description: 'Offices Under Category C',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Private offices',
      description: 'Offices Under Category C',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'NGO offices',
      description: 'Offices Under Category C',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'IT/software offices',
      description: 'Offices Under Category C',
      category: BusinessCategory.categoryC,
    ),
    BusinessSubcategory(
      name: 'Call centres',
      description: 'Offices Under Category C',
      category: BusinessCategory.categoryC,
    ),
  ];
}
