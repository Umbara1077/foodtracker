/** Lightweight offline food estimates used when Workers AI is unavailable. */

export type MacroEstimate = {
	name: string;
	calories: number;
	protein: number;
	carbs: number;
	fat: number;
};

const FOODS: Array<{ keys: string[]; item: MacroEstimate }> = [
	{
		keys: ["egg", "eggs"],
		item: { name: "Egg", calories: 70, protein: 6, carbs: 0.5, fat: 5 },
	},
	{
		keys: ["omelette", "omelet"],
		item: { name: "Omelette (2 eggs)", calories: 180, protein: 12, carbs: 1, fat: 14 },
	},
	{
		keys: ["chicken breast", "chicken"],
		item: { name: "Chicken breast (100g)", calories: 165, protein: 31, carbs: 0, fat: 3.6 },
	},
	{
		keys: ["rice", "white rice"],
		item: { name: "Cooked rice (1 cup)", calories: 205, protein: 4, carbs: 45, fat: 0.4 },
	},
	{
		keys: ["brown rice"],
		item: { name: "Brown rice (1 cup)", calories: 215, protein: 5, carbs: 45, fat: 1.6 },
	},
	{
		keys: ["pasta", "spaghetti"],
		item: { name: "Pasta (1 cup cooked)", calories: 220, protein: 8, carbs: 43, fat: 1.3 },
	},
	{
		keys: ["avocado"],
		item: { name: "Avocado (half)", calories: 120, protein: 1.5, carbs: 6, fat: 11 },
	},
	{
		keys: ["banana"],
		item: { name: "Banana", calories: 105, protein: 1.3, carbs: 27, fat: 0.4 },
	},
	{
		keys: ["apple"],
		item: { name: "Apple", calories: 95, protein: 0.5, carbs: 25, fat: 0.3 },
	},
	{
		keys: ["oatmeal", "oats"],
		item: { name: "Oatmeal (1 cup cooked)", calories: 150, protein: 5, carbs: 27, fat: 3 },
	},
	{
		keys: ["yogurt", "greek yogurt"],
		item: { name: "Greek yogurt (170g)", calories: 100, protein: 17, carbs: 6, fat: 0.7 },
	},
	{
		keys: ["salmon"],
		item: { name: "Salmon (100g)", calories: 208, protein: 20, carbs: 0, fat: 13 },
	},
	{
		keys: ["bread", "toast"],
		item: { name: "Bread slice", calories: 80, protein: 3, carbs: 15, fat: 1 },
	},
	{
		keys: ["coffee", "latte"],
		item: { name: "Coffee with milk", calories: 40, protein: 2, carbs: 4, fat: 1.5 },
	},
	{
		keys: ["pizza"],
		item: { name: "Pizza slice", calories: 285, protein: 12, carbs: 36, fat: 10 },
	},
	{
		keys: ["burger", "hamburger"],
		item: { name: "Hamburger", calories: 350, protein: 17, carbs: 33, fat: 17 },
	},
	{
		keys: ["salad"],
		item: { name: "Mixed salad", calories: 80, protein: 3, carbs: 10, fat: 3 },
	},
	{
		keys: ["protein shake", "whey"],
		item: { name: "Protein shake", calories: 120, protein: 24, carbs: 3, fat: 1 },
	},
	{
		keys: ["milk"],
		item: { name: "Milk (1 cup)", calories: 150, protein: 8, carbs: 12, fat: 8 },
	},
	{
		keys: ["cheese"],
		item: { name: "Cheese (30g)", calories: 110, protein: 7, carbs: 1, fat: 9 },
	},
];

function parseQuantity(text: string): number {
	const m = text.match(/(\d+(?:\.\d+)?)\s*(x|×)?/i);
	if (!m) return 1;
	const n = Number(m[1]);
	return Number.isFinite(n) && n > 0 ? Math.min(n, 20) : 1;
}

export function estimateFromText(raw: string): MacroEstimate {
	const text = raw.trim().toLowerCase();
	const qty = parseQuantity(text);

	for (const entry of FOODS) {
		if (entry.keys.some((k) => text.includes(k))) {
			return {
				name: qty === 1 ? entry.item.name : `${qty}× ${entry.item.name}`,
				calories: Math.round(entry.item.calories * qty),
				protein: Math.round(entry.item.protein * qty * 10) / 10,
				carbs: Math.round(entry.item.carbs * qty * 10) / 10,
				fat: Math.round(entry.item.fat * qty * 10) / 10,
			};
		}
	}

	// Generic fallback when nothing matches
	return {
		name: raw.trim() || "Meal",
		calories: Math.round(250 * qty),
		protein: Math.round(12 * qty),
		carbs: Math.round(30 * qty),
		fat: Math.round(8 * qty),
	};
}

export function inferMealType(date = new Date()): string {
	const hour = date.getHours();
	if (hour < 11) return "breakfast";
	if (hour < 15) return "lunch";
	if (hour < 21) return "dinner";
	return "snack";
}
