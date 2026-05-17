const path = require('path');

const projectId = 'likealocal-new-bb959';
const database = '(default)';

const cliLib = path.join(
  process.env.APPDATA || '',
  'npm',
  'node_modules',
  'firebase-tools',
  'lib',
);

const auth = require(path.join(cliLib, 'auth.js'));
const apiv2 = require(path.join(cliLib, 'apiv2.js'));

const ownerId = 'demo-seed-owner';

const places = [
  {
    id: 'demo-khan-el-khalili',
    title: 'Khan El Khalili Evening Walk',
    description:
      'A colorful historic market for lanterns, handmade gifts, spices, and late-night mint tea.',
    category: 'Hidden Gems',
    imageUrls: [
      'https://images.unsplash.com/photo-1572252009286-268acec5ca0a?q=80&w=1200&auto=format&fit=crop',
    ],
    location: { latitude: 30.0478, longitude: 31.2625 },
    ownerIsSuperUser: true,
    reviews: [
      ['demo-review-nour', 'Nour', 'Perfect for an evening wander and photos.', 5],
      ['demo-review-omar', 'Omar', 'Busy, but full of character.', 4],
    ],
  },
  {
    id: 'demo-zamalek-cafe',
    title: 'Quiet Zamalek Garden Cafe',
    description:
      'Leafy neighborhood cafe with calm outdoor tables, good coffee, and a laptop-friendly vibe.',
    category: 'Cafes',
    imageUrls: [
      'https://images.unsplash.com/photo-1554118811-1e0d58224f24?q=80&w=1200&auto=format&fit=crop',
    ],
    location: { latitude: 30.0626, longitude: 31.2197 },
    ownerIsSuperUser: false,
    reviews: [
      ['demo-review-laila', 'Laila', 'Great place to work for a couple of hours.', 5],
    ],
  },
  {
    id: 'demo-al-azhar-park',
    title: 'Al-Azhar Park Sunset',
    description:
      'Green views over Islamic Cairo, best around sunset with plenty of space to walk.',
    category: 'Experiences',
    imageUrls: [
      'https://images.unsplash.com/photo-1548018560-c7196548e84d?q=80&w=1200&auto=format&fit=crop',
    ],
    location: { latitude: 30.0406, longitude: 31.2653 },
    ownerIsSuperUser: true,
    reviews: [
      ['demo-review-mariam', 'Mariam', 'The skyline view is beautiful.', 5],
      ['demo-review-ali', 'Ali', 'Relaxed and clean, especially on weekdays.', 4],
    ],
  },
  {
    id: 'demo-maadi-brunch',
    title: 'Maadi Weekend Brunch Spot',
    description:
      'Casual restaurant with generous breakfast plates, fresh juice, and a relaxed weekend crowd.',
    category: 'Restaurants',
    imageUrls: [
      'https://images.unsplash.com/photo-1551218808-94e220e084d2?q=80&w=1200&auto=format&fit=crop',
    ],
    location: { latitude: 29.9602, longitude: 31.2569 },
    ownerIsSuperUser: false,
    reviews: [
      ['demo-review-salma', 'Salma', 'Cozy and very reliable for brunch.', 4],
    ],
  },
  {
    id: 'demo-downtown-rooftop',
    title: 'Downtown Rooftop Mocktails',
    description:
      'A relaxed rooftop for city views, music, and non-alcoholic drinks with friends.',
    category: 'Nightlife',
    imageUrls: [
      'https://images.unsplash.com/photo-1514933651103-005eec06c04b?q=80&w=1200&auto=format&fit=crop',
    ],
    location: { latitude: 30.0444, longitude: 31.2357 },
    ownerIsSuperUser: true,
    reviews: [
      ['demo-review-hana', 'Hana', 'The night view makes it worth it.', 5],
      ['demo-review-karim', 'Karim', 'Nice atmosphere, book ahead.', 4],
    ],
  },
  {
    id: 'demo-manial-palace',
    title: 'Manial Palace Slow Tour',
    description:
      'A peaceful palace museum with gardens, ornate rooms, and fewer crowds than the main sights.',
    category: 'Hidden Gems',
    imageUrls: [
      'https://images.unsplash.com/photo-1590050752117-238cb0fb12b1?q=80&w=1200&auto=format&fit=crop',
    ],
    location: { latitude: 30.0209, longitude: 31.2271 },
    ownerIsSuperUser: false,
    reviews: [
      ['demo-review-youssef', 'Youssef', 'Underrated and very photogenic.', 5],
    ],
  },
  {
    id: 'demo-nile-felucca',
    title: 'Nile Felucca Ride',
    description:
      'Simple river ride with a small group, best at golden hour when the breeze picks up.',
    category: 'Experiences',
    imageUrls: [
      'https://images.unsplash.com/photo-1539650116574-75c0c6d73f6e?q=80&w=1200&auto=format&fit=crop',
    ],
    location: { latitude: 30.0362, longitude: 31.2243 },
    ownerIsSuperUser: true,
    reviews: [
      ['demo-review-farida', 'Farida', 'Calm, pretty, and easy to arrange.', 5],
      ['demo-review-adam', 'Adam', 'Bring a jacket in winter.', 4],
    ],
  },
  {
    id: 'demo-heliopolis-dessert',
    title: 'Heliopolis Dessert Stop',
    description:
      'Local dessert shop known for kunafa cups, basbousa, and quick takeaway boxes.',
    category: 'Restaurants',
    imageUrls: [
      'https://images.unsplash.com/photo-1551024506-0bccd828d307?q=80&w=1200&auto=format&fit=crop',
    ],
    location: { latitude: 30.0911, longitude: 31.3223 },
    ownerIsSuperUser: false,
    reviews: [
      ['demo-review-dina', 'Dina', 'Sweet, fresh, and not overpriced.', 4],
    ],
  },
  {
    id: 'demo-garden-city-bookshop',
    title: 'Garden City Book Corner',
    description:
      'Small bookshop with used novels, travel books, and a quiet corner for browsing.',
    category: 'Hidden Gems',
    imageUrls: [
      'https://images.unsplash.com/photo-1526243741027-444d633d7365?q=80&w=1200&auto=format&fit=crop',
    ],
    location: { latitude: 30.0368, longitude: 31.2311 },
    ownerIsSuperUser: false,
    reviews: [
      ['demo-review-jana', 'Jana', 'Tiny but charming.', 4],
    ],
  },
  {
    id: 'demo-new-cairo-coffee',
    title: 'New Cairo Specialty Coffee',
    description:
      'Bright modern cafe with pour-over coffee, pastries, and plenty of seating.',
    category: 'Cafes',
    imageUrls: [
      'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?q=80&w=1200&auto=format&fit=crop',
    ],
    location: { latitude: 30.0074, longitude: 31.4913 },
    ownerIsSuperUser: false,
    reviews: [
      ['demo-review-mona', 'Mona', 'Best flat white I have tried nearby.', 5],
      ['demo-review-seif', 'Seif', 'A little loud after 7pm.', 4],
    ],
  },
];

function firestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') return { doubleValue: value };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(firestoreValue) } };
  }
  if ('latitude' in value && 'longitude' in value) {
    return { geoPointValue: value };
  }
  return {
    mapValue: {
      fields: Object.fromEntries(
        Object.entries(value).map(([key, nested]) => [key, firestoreValue(nested)]),
      ),
    },
  };
}

function document(name, data) {
  return {
    name,
    fields: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, firestoreValue(value)]),
    ),
  };
}

async function commit(writes) {
  const token = await apiv2.getAccessToken();
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/${database}/documents:commit`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ writes }),
    },
  );

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Firestore commit failed ${response.status}: ${body}`);
  }
}

async function main() {
  const account = auth.getGlobalDefaultAccount();
  if (!account) {
    throw new Error('No Firebase CLI account found. Run firebase login first.');
  }

  auth.setActiveAccount({}, account);

  const now = new Date();
  const writes = [];

  for (const place of places) {
    const ratings = place.reviews.map((review) => review[3]);
    const averageRating =
      ratings.reduce((sum, rating) => sum + rating, 0) / ratings.length;
    const placeName = `projects/${projectId}/databases/${database}/documents/places/${place.id}`;

    writes.push({
      update: document(placeName, {
        title: place.title,
        description: place.description,
        category: place.category,
        imageUrls: place.imageUrls,
        location: place.location,
        ownerId,
        ownerIsSuperUser: place.ownerIsSuperUser,
        averageRating,
        createdAt: now,
        updatedAt: now,
      }),
    });

    for (const [reviewId, userName, text, rating] of place.reviews) {
      writes.push({
        update: document(`${placeName}/reviews/${reviewId}`, {
          userId: reviewId,
          userEmail: `${userName.toLowerCase()}@example.com`,
          userName,
          text,
          rating,
          createdAt: now,
          updatedAt: now,
        }),
      });
    }
  }

  for (let i = 0; i < writes.length; i += 400) {
    await commit(writes.slice(i, i + 400));
  }

  console.log(`Seeded ${places.length} places and reviews into ${projectId}.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
