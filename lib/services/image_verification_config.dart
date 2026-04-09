/// Configuration for image verification (Cloud Vision + ML Kit fallback).
class ImageVerificationConfig {
  /// Minimum confidence threshold for ML Kit on-device labeler.
  static const double mlKitMinConfidence = 0.45;

  /// Maximum characters of detected text allowed in a travel photo.
  /// Images with more text than this are rejected as non-photo content
  /// (cards, posters, screenshots, menus, invitations, etc.).
  static const int maxAllowedTextLength = 25;

  // ── STRONG travel keywords ────────────────────────────────────────────────
  // Specific to tourist destinations. ANY match → image is approved.
  // These are deliberately narrow — generic nature words are excluded.
  static const List<String> travelKeywords = [
    // Monuments & architecture
    'monument', 'landmark', 'historical', 'heritage', 'ruins', 'ancient',
    'architecture', 'tower', 'castle', 'palace', 'fort', 'fortress',
    'citadel', 'wall', 'gate', 'arch', 'column', 'pillar', 'dome',
    'minaret', 'mosque', 'temple', 'church', 'cathedral', 'shrine',
    'mausoleum', 'museum', 'basilica', 'abbey', 'stupa', 'pagoda',
    'pyramid', 'statue', 'sculpture', 'fountain', 'bridge', 'aqueduct',
    'amphitheatre', 'colosseum', 'arena', 'plaza', 'minar',
    // Natural landmarks (specific, not generic)
    'mountain', 'hill', 'highland', 'valley', 'canyon', 'gorge', 'cliff',
    'glacier', 'volcano', 'crater', 'waterfall', 'river', 'lake',
    'reservoir', 'ocean', 'sea', 'beach', 'coast', 'bay', 'fjord',
    'island', 'peninsula', 'desert', 'dune', 'forest', 'jungle',
    'rainforest', 'woodland', 'savanna', 'wetland', 'coral reef',
    // Travel-specific scene labels
    'landscape', 'panorama', 'horizon', 'wilderness', 'national park',
    'wildlife reserve', 'tourist', 'tourist attraction', 'viewpoint',
    'overlook', 'scenic', 'vista',
    // Urban travel
    'skyline', 'cityscape', 'marketplace', 'bazaar', 'waterfront',
    'harbour', 'port', 'botanical garden', 'zoo', 'theme park',
    // Specific outdoor scenes
    'sunset', 'sunrise', 'twilight',
  ];

  // ── Outdoor scene keywords (kept for ML Kit face-context check) ──────────
  static const List<String> outdoorSceneKeywords = [
    'building', 'architecture', 'landscape', 'mountain', 'water',
    'road', 'street', 'monument', 'beach', 'forest', 'scenery', 'wall',
  ];

  // ── Hard-reject label keywords ────────────────────────────────────────────
  // Any match → image is rejected as non-photo content.
  static const List<String> rejectedKeywords = [
    // Graphics / digital art
    'logo', 'brand', 'font', 'text', 'typography', 'lettering',
    'graphic design', 'illustration', 'clipart', 'cartoon', 'anime',
    'digital art', 'art',
    // Print / paper media
    'screenshot', 'advertising', 'poster', 'banner', 'flyer',
    'document', 'paper', 'book', 'magazine', 'newspaper', 'brochure',
    'menu', 'receipt', 'label', 'sticker',
    // Events / celebrations (cards, invitations, decor)
    'invitation', 'greeting card', 'wedding', 'party', 'ceremony',
    'celebration', 'event', 'birthday', 'ribbon', 'bow', 'ornament',
    'decoration', 'balloon', 'confetti', 'candle',
    // Textiles / fabric close-ups
    'lace', 'textile', 'fabric', 'pattern',
    // Other
    'meme', 'infographic', 'diagram', 'chart',
  ];
}
