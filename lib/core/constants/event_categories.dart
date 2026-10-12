class EventCategories {
  static const labels = {
    'technology': 'Technology',
    'sport': 'Sport',
    'workshop': 'Workshop',
    'music': 'Music',
  };
  static String label(String category) => labels[category] ?? category;
}
