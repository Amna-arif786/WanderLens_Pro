class ImageVerificationConfig {
  // Broad list of travel and nature keywords
  static const List<String> allowedKeywords = [
    'tree', 'mountain', 'sky', 'landmark', 'sun', 'river', 'lake', 'nature', 'forest', 
    'cloud', 'building', 'monument', 'historical site', 'architecture', 'outdoor', 
    'landscape', 'water', 'ocean', 'beach', 'valley', 'hill', 'park', 'garden', 
    'temple', 'tower', 'bridge', 'castle', 'palace', 'statue', 'sculpture',
    'mountain range', 'snow', 'winter', 'wilderness', 'plant', 'scenery', 'highland',
    'rock', 'glacier', 'natural landscape', 'geological phenomenon', 'horizon'
  ];

  static const List<String> rejectedKeywords = [
    'logo', 'graphic design', 'font', 'brand', 'text', 'screenshot', 'advertising', 
    'illustration', 'clipart', 'poster', 'document'
  ];

  // Lowered confidence for better UX on device
  static const double minConfidence = 0.4; 
}
