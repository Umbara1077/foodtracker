import { FormEvent, useEffect, useMemo, useRef, useState } from "react";
import "./App.css";

type Meal = {
	id: string;
	eaten_at: string;
	meal_type: string;
	name: string;
	calories: number;
	protein: number;
	carbs: number;
	fat: number;
	notes: string | null;
};

type Totals = {
	calories: number;
	protein: number;
	carbs: number;
	fat: number;
	count: number;
};

type Goals = {
	calories: number;
	protein: number;
	carbs: number;
	fat: number;
};

const EMPTY_TOTALS: Totals = {
	calories: 0,
	protein: 0,
	carbs: 0,
	fat: 0,
	count: 0,
};

function todayISO() {
	const d = new Date();
	const offset = d.getTimezoneOffset();
	const local = new Date(d.getTime() - offset * 60_000);
	return local.toISOString().slice(0, 10);
}

function shiftDay(iso: string, delta: number) {
	const d = new Date(`${iso}T12:00:00`);
	d.setDate(d.getDate() + delta);
	return d.toISOString().slice(0, 10);
}

function formatDay(iso: string) {
	const d = new Date(`${iso}T12:00:00`);
	return d.toLocaleDateString(undefined, {
		weekday: "long",
		month: "short",
		day: "numeric",
	});
}

function pct(value: number, goal: number) {
	if (!goal) return 0;
	return Math.min(100, Math.round((value / goal) * 100));
}

function Ring({ value, goal }: { value: number; goal: number }) {
	const r = 54;
	const c = 2 * Math.PI * r;
	const p = Math.min(1, goal ? value / goal : 0);
	const offset = c * (1 - p);
	return (
		<div className="ring-wrap" aria-hidden="true">
			<svg viewBox="0 0 140 140">
				<circle className="ring-track" cx="70" cy="70" r={r} />
				<circle
					className="ring-value"
					cx="70"
					cy="70"
					r={r}
					strokeDasharray={c}
					strokeDashoffset={offset}
				/>
			</svg>
			<div className="ring-label">
				<strong>{Math.round(value)}</strong>
				<span>of {Math.round(goal)} kcal</span>
			</div>
		</div>
	);
}

export default function App() {
	const [day, setDay] = useState(todayISO);
	const [meals, setMeals] = useState<Meal[]>([]);
	const [totals, setTotals] = useState<Totals>(EMPTY_TOTALS);
	const [goals, setGoals] = useState<Goals>({
		calories: 2000,
		protein: 150,
		carbs: 200,
		fat: 65,
	});
	const [text, setText] = useState("");
	const [mealType, setMealType] = useState("auto");
	const [macros, setMacros] = useState({
		calories: "",
		protein: "",
		carbs: "",
		fat: "",
	});
	const [status, setStatus] = useState("");
	const [error, setError] = useState("");
	const [busy, setBusy] = useState(false);
	const logRef = useRef<HTMLTextAreaElement>(null);

	const remaining = useMemo(
		() => Math.max(0, goals.calories - totals.calories),
		[goals.calories, totals.calories],
	);

	async function loadDay(nextDay: string) {
		setError("");
		const [mealsRes, goalsRes] = await Promise.all([
			fetch(`/api/meals?date=${nextDay}`),
			fetch("/api/goals"),
		]);
		if (!mealsRes.ok) throw new Error("Could not load meals");
		const mealsData = (await mealsRes.json()) as {
			meals: Meal[];
			totals: Totals;
		};
		setMeals(mealsData.meals);
		setTotals(mealsData.totals);
		if (goalsRes.ok) {
			setGoals((await goalsRes.json()) as Goals);
		}
	}

	useEffect(() => {
		loadDay(day).catch((err: unknown) => {
			setError(err instanceof Error ? err.message : "Failed to load");
		});
	}, [day]);

	function focusLog() {
		logRef.current?.focus();
		logRef.current?.scrollIntoView({ behavior: "smooth", block: "center" });
	}

	async function estimate() {
		if (!text.trim()) return;
		setBusy(true);
		setStatus("Estimating…");
		setError("");
		try {
			const res = await fetch("/api/estimate", {
				method: "POST",
				headers: { "Content-Type": "application/json" },
				body: JSON.stringify({ text }),
			});
			if (!res.ok) throw new Error("Estimate failed");
			const data = (await res.json()) as {
				name: string;
				calories: number;
				protein: number;
				carbs: number;
				fat: number;
				source: string;
				meal_type: string;
			};
			setText(data.name);
			setMacros({
				calories: String(data.calories),
				protein: String(data.protein),
				carbs: String(data.carbs),
				fat: String(data.fat),
			});
			if (mealType === "auto") setMealType(data.meal_type);
			setStatus("Estimated from the local food library");
		} catch (err: unknown) {
			setError(err instanceof Error ? err.message : "Estimate failed");
			setStatus("");
		} finally {
			setBusy(false);
		}
	}

	async function onSubmit(e: FormEvent) {
		e.preventDefault();
		if (!text.trim()) return;
		setBusy(true);
		setError("");
		setStatus("Saving…");
		try {
			const payload: Record<string, unknown> = {
				text: text.trim(),
				name: text.trim(),
				estimate: !macros.calories,
			};
			if (mealType !== "auto") payload.meal_type = mealType;
			if (macros.calories) payload.calories = Number(macros.calories);
			if (macros.protein) payload.protein = Number(macros.protein);
			if (macros.carbs) payload.carbs = Number(macros.carbs);
			if (macros.fat) payload.fat = Number(macros.fat);
			if (day !== todayISO()) {
				payload.eaten_at = `${day}T12:00:00.000Z`;
			}

			const res = await fetch("/api/meals", {
				method: "POST",
				headers: { "Content-Type": "application/json" },
				body: JSON.stringify(payload),
			});
			if (!res.ok) throw new Error("Could not save meal");
			setText("");
			setMacros({ calories: "", protein: "", carbs: "", fat: "" });
			setMealType("auto");
			setStatus("Logged");
			await loadDay(day);
		} catch (err: unknown) {
			setError(err instanceof Error ? err.message : "Save failed");
			setStatus("");
		} finally {
			setBusy(false);
		}
	}

	async function removeMeal(id: string) {
		setError("");
		const res = await fetch(`/api/meals/${id}`, { method: "DELETE" });
		if (!res.ok) {
			setError("Could not delete meal");
			return;
		}
		await loadDay(day);
	}

	return (
		<main className="shell">
			<section className="hero">
				<h1 className="brand">
					Food<span>tracker</span>
				</h1>
				<p className="tagline">
					Type what you ate in plain language. We estimate the macros and keep
					today&apos;s plate honest.
				</p>
				<div className="hero-actions">
					<button type="button" className="btn btn-primary" onClick={focusLog}>
						Log a meal
					</button>
					<button
						type="button"
						className="btn btn-ghost"
						onClick={() => setDay(todayISO())}
					>
						Jump to today
					</button>
				</div>
			</section>

			<section className="panel" aria-labelledby="today-heading">
				<div className="date-nav">
					<button
						type="button"
						className="icon-btn"
						aria-label="Previous day"
						onClick={() => setDay((d) => shiftDay(d, -1))}
					>
						←
					</button>
					<strong id="today-heading">{formatDay(day)}</strong>
					<button
						type="button"
						className="icon-btn"
						aria-label="Next day"
						onClick={() => setDay((d) => shiftDay(d, 1))}
					>
						→
					</button>
				</div>
				<p className="lead">
					{remaining > 0
						? `${Math.round(remaining)} kcal still on the table.`
						: "You've hit today's calorie goal."}
				</p>
				<div className="progress-grid">
					<Ring value={totals.calories} goal={goals.calories} />
					<ul className="macro-list">
						{(
							[
								["Protein", totals.protein, goals.protein, "g"],
								["Carbs", totals.carbs, goals.carbs, "g"],
								["Fat", totals.fat, goals.fat, "g"],
							] as const
						).map(([label, value, goal, unit]) => (
							<li key={label}>
								<div className="macro-row">
									<span>{label}</span>
									<span>
										{Math.round(value)}
										{unit} / {Math.round(goal)}
										{unit}
									</span>
								</div>
								<div className="bar" aria-hidden="true">
									<i style={{ width: `${pct(value, goal)}%` }} />
								</div>
							</li>
						))}
					</ul>
				</div>
			</section>

			<section className="panel" aria-labelledby="log-heading">
				<h2 id="log-heading">Quick log</h2>
				<p className="lead">
					Try “2 eggs and toast” or “chicken rice bowl” — estimate, tweak, save.
				</p>
				<form className="composer" onSubmit={onSubmit}>
					<label>
						What did you eat?
						<textarea
							ref={logRef}
							rows={2}
							value={text}
							onChange={(e) => setText(e.target.value)}
							placeholder="had oatmeal with banana for breakfast"
							required
						/>
					</label>
					<label>
						Meal
						<select
							value={mealType}
							onChange={(e) => setMealType(e.target.value)}
						>
							<option value="auto">Auto</option>
							<option value="breakfast">Breakfast</option>
							<option value="lunch">Lunch</option>
							<option value="dinner">Dinner</option>
							<option value="snack">Snack</option>
						</select>
					</label>
					<div className="composer-row">
						<label>
							kcal
							<input
								inputMode="decimal"
								value={macros.calories}
								onChange={(e) =>
									setMacros((m) => ({ ...m, calories: e.target.value }))
								}
								placeholder="auto"
							/>
						</label>
						<label>
							protein
							<input
								inputMode="decimal"
								value={macros.protein}
								onChange={(e) =>
									setMacros((m) => ({ ...m, protein: e.target.value }))
								}
								placeholder="g"
							/>
						</label>
						<label>
							carbs
							<input
								inputMode="decimal"
								value={macros.carbs}
								onChange={(e) =>
									setMacros((m) => ({ ...m, carbs: e.target.value }))
								}
								placeholder="g"
							/>
						</label>
						<label>
							fat
							<input
								inputMode="decimal"
								value={macros.fat}
								onChange={(e) =>
									setMacros((m) => ({ ...m, fat: e.target.value }))
								}
								placeholder="g"
							/>
						</label>
					</div>
					<div className="composer-actions">
						<button
							type="button"
							className="btn btn-ghost"
							style={{ color: "var(--brand)", background: "rgba(20,53,46,0.08)" }}
							onClick={estimate}
							disabled={busy || !text.trim()}
						>
							Estimate
						</button>
						<button
							type="submit"
							className="btn btn-primary"
							disabled={busy || !text.trim()}
						>
							Save meal
						</button>
						<p className={`status ${error ? "error" : ""}`}>
							{error || status}
						</p>
					</div>
					<p className="hint">
						Estimates use a built-in food library. You can tweak the macros
						before saving.
					</p>
				</form>
			</section>

			<section className="panel" aria-labelledby="meals-heading">
				<h2 id="meals-heading">Today&apos;s plate</h2>
				{meals.length === 0 ? (
					<p className="empty">Nothing logged yet. Your first bite starts here.</p>
				) : (
					<ul className="meal-list">
						{meals.map((meal) => (
							<li key={meal.id} className="meal-item">
								<span className="meal-badge">{meal.meal_type}</span>
								<div>
									<h3>{meal.name}</h3>
									<p>
										P {Math.round(meal.protein)}g · C {Math.round(meal.carbs)}g ·
										F {Math.round(meal.fat)}g
									</p>
								</div>
								<div style={{ textAlign: "right" }}>
									<div className="meal-cal">{Math.round(meal.calories)} kcal</div>
									<button
										type="button"
										className="btn btn-danger"
										onClick={() => removeMeal(meal.id)}
									>
										Remove
									</button>
								</div>
							</li>
						))}
					</ul>
				)}
			</section>
		</main>
	);
}
