import 'dart:math' show Random;

/// The words a family code is made of: 256 plain words, so six of them give
/// 48 bits.
const familyWords = [
  'acorn', 'actor', 'agent', 'album', 'alarm', 'anchor', 'angel', 'ankle', //
  'apple', 'apron', 'arrow', 'atlas', 'attic', 'aunt', 'autumn', 'badge',
  'bagel', 'banana', 'banjo', 'barn', 'basket', 'beach', 'beads', 'beard',
  'bell', 'bench', 'berry', 'bike', 'bird', 'blanket', 'boat', 'bottle',
  'bread', 'brick', 'bridge', 'brush', 'bubble', 'bucket', 'button', 'cabin',
  'cake', 'camel', 'camera', 'candle', 'canoe', 'carrot', 'castle', 'cave',
  'chair', 'chalk', 'cheese', 'cherry', 'chess', 'chick', 'circle', 'cliff',
  'clock', 'cloud', 'clown', 'coat', 'coconut', 'comet', 'cookie', 'coral',
  'corn', 'cotton', 'cow', 'crab', 'crayon', 'cricket', 'crown', 'cup',
  'daisy', 'desert', 'diary', 'dinner', 'doctor', 'dolphin', 'donkey', 'door',
  'dragon', 'drum', 'duck', 'eagle', 'earth', 'echo', 'egg', 'elbow',
  'elf', 'engine', 'fairy', 'farmer', 'feather', 'fence', 'field', 'finger',
  'fish', 'flag', 'flower', 'flute', 'forest', 'fox', 'frog', 'garden',
  'ginger', 'giraffe', 'glass', 'glove', 'goat', 'grape', 'grass', 'guitar',
  'hammer', 'harbour', 'hat', 'hill', 'honey', 'horse', 'house', 'igloo',
  'island', 'jacket', 'jam', 'jelly', 'jungle', 'kettle', 'key', 'kite',
  'kitten', 'koala', 'ladder', 'lake', 'lamp', 'lemon', 'leopard', 'letter',
  'lion', 'lizard', 'lotus', 'magnet', 'mango', 'map', 'marble', 'meadow',
  'melon', 'mirror', 'monkey', 'moon', 'mountain', 'mouse', 'muffin', 'nest',
  'net', 'noodle', 'ocean', 'olive', 'onion', 'orange', 'otter', 'owl',
  'paddle', 'panda', 'paper', 'parrot', 'peach', 'peacock', 'pear', 'pebble',
  'pencil', 'penguin', 'pepper', 'piano', 'pillow', 'pilot', 'pizza', 'planet',
  'plum', 'pocket', 'pond', 'potato', 'puppy', 'puzzle', 'quilt', 'rabbit',
  'radio', 'rain', 'rainbow', 'river', 'robot', 'rocket', 'roof', 'rope',
  'rose', 'sailor', 'salad', 'sand', 'saucer', 'scarf', 'school', 'seal',
  'shadow', 'shell', 'ship', 'shoe', 'silver', 'skate', 'sky', 'snail',
  'snow', 'sock', 'sofa', 'spider', 'spoon', 'squirrel', 'star', 'stone',
  'storm', 'sugar', 'summer', 'sun', 'swan', 'table', 'teapot', 'tent',
  'thunder', 'tiger', 'toast', 'tomato', 'torch', 'tower', 'tractor', 'train',
  'tree', 'trumpet', 'tulip', 'turtle', 'umbrella', 'valley', 'van', 'violin',
  'wagon', 'walnut', 'water', 'whale', 'wheel', 'window', 'winter', 'wolf',
  'yak', 'yogurt', 'zebra', 'zipper', 'bean', 'bear', 'bee', 'cat',
];

/// Six words picked at random.
List<String> makeFamilyCode(Random random) => [
  for (var i = 0; i < 6; i++) familyWords[random.nextInt(familyWords.length)],
];

/// The six words of [typed], in lower case; null unless it is six words of
/// the list.
List<String>? readFamilyCode(String typed) {
  final words = typed
      .toLowerCase()
      .split(RegExp(r'[\s,.]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.length != 6 || !words.every(familyWords.contains)) return null;
  return words;
}
