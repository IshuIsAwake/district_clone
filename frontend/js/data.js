// Static mirror of the Zomato District database seed, shaped for the
// front-end pages. One object per table - keeps the UI decoupled from SQL
// so the site can be hosted on GitHub Pages.

const CATEGORIES = [
  { id: 1, name: "Live Music",    accent: "#e63946" },
  { id: 2, name: "Comedy",        accent: "#f4a261" },
  { id: 3, name: "DJ Night",      accent: "#9d4edd" },
  { id: 4, name: "Food Festival", accent: "#2a9d8f" },
  { id: 5, name: "Workshop",      accent: "#457b9d" },
  { id: 6, name: "Theatre",       accent: "#c77dff" },
  { id: 7, name: "Sports",        accent: "#e76f51" }
];

const LOCATIONS = [
  { id: 1, venue: "Jawaharlal Nehru Stadium",    city: "Delhi",     state: "Delhi",       locality: "Lodhi Road",  pin: "110003", capacity: 5000 },
  { id: 2, venue: "NSCI Dome",                   city: "Mumbai",    state: "Maharashtra", locality: "Worli",       pin: "400018", capacity: 4000 },
  { id: 3, venue: "Phoenix Marketcity",          city: "Bangalore", state: "Karnataka",   locality: "Whitefield",  pin: "560066", capacity: 2500 },
  { id: 4, venue: "Kingdom of Dreams",           city: "Gurugram",  state: "Haryana",     locality: "Sector 29",   pin: "122002", capacity: 1500 },
  { id: 5, venue: "Bangalore Palace Grounds",    city: "Bangalore", state: "Karnataka",   locality: "Palace Road", pin: "560052", capacity: 8000 },
  { id: 6, venue: "Famous Studios",              city: "Mumbai",    state: "Maharashtra", locality: "Mahalaxmi",   pin: "400011", capacity: 800 },
  { id: 7, venue: "Indira Gandhi Indoor Stadium",city: "Delhi",     state: "Delhi",       locality: "ITO",         pin: "110002", capacity: 4500 }
];

const HOSTS = [
  { id: 1, name: "BookMyShow Live",       email: "live@bms.in" },
  { id: 2, name: "Sunburn Events",        email: "contact@sunburn.in" },
  { id: 3, name: "District Comedy Co",    email: "hello@districtcomedy.in" },
  { id: 4, name: "Bacardi NH7 Weekender", email: "nh7@bacardi.in" },
  { id: 5, name: "Paytm Insider",         email: "ops@insider.in" }
];

const PERFORMERS = [
  { id: 1, name: "Prateek Kuhad",     type: "Singer" },
  { id: 2, name: "Zakir Khan",        type: "Comedian" },
  { id: 3, name: "Nucleya",           type: "DJ" },
  { id: 4, name: "The Local Train",   type: "Band" },
  { id: 5, name: "Kanan Gill",        type: "Comedian" },
  { id: 6, name: "Ritviz",            type: "DJ" },
  { id: 7, name: "Parvaaz",           type: "Band" },
  { id: 8, name: "Biswa Kalyan Rath", type: "Comedian" }
];

const OFFERS = [
  { id: 1, code: "FIRST50",   type: "percentage", value: 50,  active: true },
  { id: 2, code: "EARLYBIRD", type: "percentage", value: 20,  active: true },
  { id: 3, code: "ZOMATO10",  type: "percentage", value: 10,  active: true },
  { id: 4, code: "GROUP25",   type: "percentage", value: 25,  active: true },
  { id: 5, code: "WEEKEND15", type: "flat",       value: 150, active: true }
];

const EVENTS = [
  {
    id: 1,
    title: "Prateek Kuhad Live",
    date: "2026-05-10",
    start_time: "19:30",
    duration: 120,
    age_limit: 12,
    seats_available: 446,
    price: 1999,
    description: "An intimate evening of indie folk with chart-topping singer-songwriter Prateek Kuhad. Expect cold/mess favourites alongside material from the new record.",
    category_id: 1,
    location_id: 1,
    host_id: 1,
    performer_ids: [1]
  },
  {
    id: 2,
    title: "Zakir Khan: Mann Pasand",
    date: "2026-05-22",
    start_time: "20:00",
    duration: 90,
    age_limit: 15,
    seats_available: 197,
    price: 1499,
    description: "Sakht launda turns storyteller in his most personal set yet. An hour of Urdu, shayari and perfectly timed silences.",
    category_id: 2,
    location_id: 2,
    host_id: 3,
    performer_ids: [2]
  },
  {
    id: 3,
    title: "Sunburn Arena ft. Nucleya",
    date: "2026-06-05",
    start_time: "21:00",
    duration: 180,
    age_limit: 18,
    seats_available: 295,
    price: 2499,
    description: "Basslines, beats and the unmistakable Nucleya bounce in a high-energy club night. Full production, international lasers, single GA floor.",
    category_id: 3,
    location_id: 3,
    host_id: 2,
    performer_ids: [3]
  },
  {
    id: 4,
    title: "Bangalore Street Food Fest",
    date: "2026-05-15",
    start_time: "12:00",
    duration: 480,
    age_limit: 0,
    seats_available: 498,
    price: 299,
    description: "Over 60 stalls curated from every corner of the country. Live music stage, craft bar, kid-friendly zones and a sunset film screening.",
    category_id: 4,
    location_id: 5,
    host_id: 5,
    performer_ids: []
  },
  {
    id: 5,
    title: "The Local Train Unplugged",
    date: "2026-06-12",
    start_time: "19:00",
    duration: 150,
    age_limit: 14,
    seats_available: 247,
    price: 1299,
    description: "The band strips down their biggest hits in an acoustic-only set. Expect fresh arrangements of Aaftaab, Choo Lo and Yeh Zindagi Hai.",
    category_id: 1,
    location_id: 6,
    host_id: 1,
    performer_ids: [4]
  },
  {
    id: 6,
    title: "Kanan Gill: New Material",
    date: "2026-04-28",
    start_time: "20:30",
    duration: 75,
    age_limit: 18,
    seats_available: 178,
    price: 999,
    description: "Work-in-progress night. First public outing of brand new jokes, no cameras allowed, expect bits to break and be rewritten on stage.",
    category_id: 2,
    location_id: 4,
    host_id: 3,
    performer_ids: [5]
  },
  {
    id: 7,
    title: "Bacardi NH7 Weekender Delhi",
    date: "2026-07-18",
    start_time: "16:00",
    duration: 600,
    age_limit: 18,
    seats_available: 1996,
    price: 3499,
    description: "The happiest music festival in India returns with a three-stage Delhi edition. One ticket, over 30 acts, and the most stacked lineup of the year.",
    category_id: 1,
    location_id: 7,
    host_id: 4,
    performer_ids: [4, 1, 7]
  },
  {
    id: 8,
    title: "Ritviz Live",
    date: "2026-03-20",
    start_time: "20:00",
    duration: 150,
    age_limit: 16,
    seats_available: 248,
    price: 1799,
    description: "Liggi, Udd Gaye and more - an electronic set you can actually dance to.",
    category_id: 3,
    location_id: 3,
    host_id: 2,
    performer_ids: [6]
  },
  {
    id: 9,
    title: "Biswa Stand-up Special",
    date: "2026-03-05",
    start_time: "19:30",
    duration: 90,
    age_limit: 15,
    seats_available: 177,
    price: 899,
    description: "Biswa Kalyan Rath takes apart everyday life with his signature deadpan delivery.",
    category_id: 2,
    location_id: 6,
    host_id: 3,
    performer_ids: [8]
  },
  {
    id: 10,
    title: "Parvaaz Live Acoustic",
    date: "2026-02-14",
    start_time: "18:30",
    duration: 120,
    age_limit: 0,
    seats_available: 147,
    price: 1099,
    description: "Bangalore psychedelic rock outfit in a rare Delhi acoustic performance.",
    category_id: 1,
    location_id: 4,
    host_id: 1,
    performer_ids: [7]
  }
];

const REVIEWS = [
  { event_id: 9,  reviewer: "Sneha Reddy",  rating: 5, comment: "Hilarious set, laughed till my sides hurt. Worth every rupee.",        date: "2026-03-06" },
  { event_id: 8,  reviewer: "Arjun Menon",  rating: 4, comment: "Incredible energy, wish the sound mix was a touch cleaner.",           date: "2026-03-21" },
  { event_id: 10, reviewer: "Meera Kapoor", rating: 5, comment: "Magical night. Parvaaz was soul-stirring in that small room.",         date: "2026-02-15" },
  { event_id: 10, reviewer: "Priya Nair",   rating: 4, comment: "Beautiful acoustics, the intimate venue really made it special.",       date: "2026-02-15" },
  { event_id: 9,  reviewer: "Kabir Singh",  rating: 3, comment: "Decent show but felt a bit overrated for the ticket price.",            date: "2026-03-01" }
];

// ---------- helpers ----------------------------------------------------------

function findCategory(id)  { return CATEGORIES.find(c => c.id === id); }
function findLocation(id)  { return LOCATIONS.find(l => l.id === id); }
function findHost(id)      { return HOSTS.find(h => h.id === id); }
function findPerformer(id) { return PERFORMERS.find(p => p.id === id); }
function findOffer(code)   { return OFFERS.find(o => o.code.toUpperCase() === code.toUpperCase() && o.active); }
function findEvent(id)     { return EVENTS.find(e => e.id === Number(id)); }
function reviewsFor(id)    { return REVIEWS.filter(r => r.event_id === Number(id)); }

function formatRupees(n) {
  return "Rs " + Number(n).toLocaleString("en-IN");
}

function formatDate(iso) {
  const d = new Date(iso + "T00:00:00");
  return d.toLocaleDateString("en-IN", { weekday: "short", day: "2-digit", month: "short", year: "numeric" });
}

function formatTime(hhmm) {
  const [h, m] = hhmm.split(":").map(Number);
  const period = h >= 12 ? "PM" : "AM";
  const h12 = ((h + 11) % 12) + 1;
  return `${h12}:${String(m).padStart(2, "0")} ${period}`;
}

function isUpcoming(iso) {
  const today = new Date().toISOString().slice(0, 10);
  return iso >= today;
}

function applyOffer(amount, code) {
  const offer = findOffer(code);
  if (!offer) return { valid: false, final: amount, discount: 0 };
  let discount = 0;
  if (offer.type === "percentage") discount = Math.round(amount * offer.value) / 100;
  else                              discount = offer.value;
  const final = Math.max(0, amount - discount);
  return { valid: true, final, discount, offer };
}
