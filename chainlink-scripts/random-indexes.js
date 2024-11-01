const size = parseInt(args[0]);
if (!size || size <= 0) {
  throw Error("Invalid size argument");
}

try {
  // Create array 0-99
  const numbers = Array.from({ length: 100 }, (_, i) => i);
  
  // Fisher-Yates shuffle using Math.random
  for (let i = numbers.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [numbers[i], numbers[j]] = [numbers[j], numbers[i]];
  }
  
  // Take first N numbers
  const result = numbers.slice(0, size);
  
  return Functions.encodeString(result.join(","));
  
} catch (error) {
  throw error;
}
