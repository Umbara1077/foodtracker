import { Hono } from "hono";
import { cors } from "hono/cors";
import { estimateFromText, inferMealType } from "./food-db";

type MealRow = {
	id: string;
	eaten_at: string;
	meal_type: string;
	name: string;
	calories: number;
	protein: number;
	carbs: number;
	fat: number;
	notes: string | null;
	created_at: string;
};

type GoalsRow = {
	calories: number;
	protein: number;
	carbs: number;
	fat: number;
};

const app = new Hono<{ Bindings: Env }>();

app.use("/api/*", cors());

app.get("/api/health", (c) =>
	c.json({ ok: true, service: "foodtracker", ts: new Date().toISOString() }),
);

app.get("/api/goals", async (c) => {
	const row = await c.env.DB.prepare(
		"SELECT calories, protein, carbs, fat FROM goals WHERE id = 1",
	).first<GoalsRow>();
	return c.json(
		row ?? { calories: 2000, protein: 150, carbs: 200, fat: 65 },
	);
});

app.put("/api/goals", async (c) => {
	const body = await c.req.json<{
		calories?: number;
		protein?: number;
		carbs?: number;
		fat?: number;
	}>();
	await c.env.DB.prepare(
		`UPDATE goals SET
			calories = COALESCE(?, calories),
			protein = COALESCE(?, protein),
			carbs = COALESCE(?, carbs),
			fat = COALESCE(?, fat)
		 WHERE id = 1`,
	)
		.bind(
			body.calories ?? null,
			body.protein ?? null,
			body.carbs ?? null,
			body.fat ?? null,
		)
		.run();
	const row = await c.env.DB.prepare(
		"SELECT calories, protein, carbs, fat FROM goals WHERE id = 1",
	).first<GoalsRow>();
	return c.json(row);
});

app.get("/api/meals", async (c) => {
	const day = c.req.query("date") ?? new Date().toISOString().slice(0, 10);
	const { results } = await c.env.DB.prepare(
		`SELECT * FROM meals
		 WHERE date(eaten_at) = date(?)
		 ORDER BY eaten_at ASC`,
	)
		.bind(day)
		.all<MealRow>();

	const totals = (results ?? []).reduce(
		(acc, m) => ({
			calories: acc.calories + m.calories,
			protein: acc.protein + m.protein,
			carbs: acc.carbs + m.carbs,
			fat: acc.fat + m.fat,
			count: acc.count + 1,
		}),
		{ calories: 0, protein: 0, carbs: 0, fat: 0, count: 0 },
	);

	return c.json({ date: day, meals: results ?? [], totals });
});

app.post("/api/estimate", async (c) => {
	const body = await c.req.json<{ text?: string }>();
	const text = (body.text ?? "").trim();
	if (!text) return c.json({ error: "text is required" }, 400);

	const estimate = estimateFromText(text);
	return c.json({ ...estimate, source: "local" as const, meal_type: inferMealType() });
});

app.post("/api/meals", async (c) => {
	const body = await c.req.json<{
		name?: string;
		text?: string;
		calories?: number;
		protein?: number;
		carbs?: number;
		fat?: number;
		meal_type?: string;
		eaten_at?: string;
		notes?: string;
		estimate?: boolean;
	}>();

	let name = (body.name ?? "").trim();
	let calories = Number(body.calories ?? NaN);
	let protein = Number(body.protein ?? 0);
	let carbs = Number(body.carbs ?? 0);
	let fat = Number(body.fat ?? 0);

	if (body.estimate || (!Number.isFinite(calories) && body.text)) {
		const estimate = estimateFromText(body.text || name);
		name = name || estimate.name;
		calories = Number.isFinite(calories) ? calories : estimate.calories;
		protein = body.protein ?? estimate.protein;
		carbs = body.carbs ?? estimate.carbs;
		fat = body.fat ?? estimate.fat;
	}

	if (!name) return c.json({ error: "name is required" }, 400);
	if (!Number.isFinite(calories)) return c.json({ error: "calories required" }, 400);

	const id = crypto.randomUUID();
	const eatenAt = body.eaten_at ?? new Date().toISOString();
	const mealType = body.meal_type ?? inferMealType(new Date(eatenAt));

	await c.env.DB.prepare(
		`INSERT INTO meals (id, eaten_at, meal_type, name, calories, protein, carbs, fat, notes)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
	)
		.bind(
			id,
			eatenAt,
			mealType,
			name,
			calories,
			protein,
			carbs,
			fat,
			body.notes ?? null,
		)
		.run();

	const meal = await c.env.DB.prepare("SELECT * FROM meals WHERE id = ?")
		.bind(id)
		.first<MealRow>();
	return c.json(meal, 201);
});

app.delete("/api/meals/:id", async (c) => {
	const id = c.req.param("id");
	const existing = await c.env.DB.prepare(
		"SELECT id FROM meals WHERE id = ?",
	)
		.bind(id)
		.first();
	if (!existing) return c.json({ error: "not found" }, 404);
	await c.env.DB.prepare("DELETE FROM meals WHERE id = ?").bind(id).run();
	return c.json({ ok: true });
});

export default app;
