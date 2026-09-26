/**
 * SafeTour AI Chat Service
 * Handles AI chat queries with dual-engine support:
 * 1. Google Gemini AI (if GEMINI_API_KEY is present in .env)
 * 2. Specialized SafeTour Tourist Safety Knowledge Engine (offline / mock fallback)
 */

const SYSTEM_PROMPT = `
You are SafeTour AI, an intelligent, specialized tourist safety assistant and travel navigation guide.
Your primary mission is to protect travelers and provide accurate, actionable tourist safety advice.
When answering:
1. Provide specific, practical advice on safe vs. dangerous areas, local scams, navigation, night safety, and emergency contacts.
2. If asked about specific locations (e.g. Jammu & Kashmir, Delhi, Goa, Paris, etc.), explicitly outline safe tourist circuits and specific high-risk or border zones to avoid.
3. Domain boundary: If the user asks questions completely unrelated to travel, geography, tourism safety, or emergency help (e.g. solving math equations, writing computer code, gossip), politely decline by stating: "I am SafeTour AI, specialized only in travel safety and tourist guidance. Please ask me about safe places to visit, danger zones to avoid, or emergency travel assistance."
Keep your responses helpful, concise, well-structured with bullet points, and friendly for mobile users.
`;

/**
 * Call Gemini REST API (Zero-dependency, using native fetch)
 */
async function callGemini(message) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey || apiKey.trim() === '' || apiKey.includes('your_')) {
    return null;
  }

  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;

  const requestBody = {
    contents: [
      {
        role: 'user',
        parts: [
          { text: `${SYSTEM_PROMPT}\n\nUser Query: ${message}` }
        ]
      }
    ],
    generationConfig: {
      maxOutputTokens: 500,
      temperature: 0.4
    }
  };

  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody)
    });

    if (!response.ok) {
      const errText = await response.text();
      console.warn('Gemini API call failed, falling back to local engine:', errText);
      return null;
    }

    const data = await response.json();
    const candidate = data.candidates?.[0]?.content?.parts?.[0]?.text;
    return candidate || null;
  } catch (error) {
    console.error('Error calling Gemini API:', error.message);
    return null;
  }
}

/**
 * Intelligent SafeTour Tourist Safety Knowledge Engine (Fallback)
 */
function getKnowledgeResponse(message) {
  const lower = message.toLowerCase().trim();

  // 1. Greetings
  if (/^(hi|hello|hey|greetings|good morning|good afternoon|good evening)\b/.test(lower) || lower === 'hi' || lower === 'hello') {
    return "Hello! I am SafeTour AI, your 24/7 travel safety assistant. I can help you with:\n• Safe places to visit & zones to avoid in any destination\n• Local tourist safety tips & scam alerts\n• Emergency helpline numbers & nearby hospital/police directions\n\nWhere are you traveling or how can I help you stay safe today?";
  }

  // 2. Specific Region: Jammu & Kashmir / Kashmir / Srinagar / Ladakh
  if (lower.includes('kashmir') || lower.includes('jammu') || lower.includes('srinagar') || lower.includes('ladakh') || lower.includes('gulmarg')) {
    if (lower.includes('avoid') || lower.includes("don't") || lower.includes('danger') || lower.includes('not visit') || lower.includes('unsafe')) {
      return "For Jammu & Kashmir, here are the key safety precautions and areas to avoid:\n\n" +
        "🚫 Areas to Avoid:\n" +
        "• High-risk border zones near the Line of Control (LOC) such as Uri, Kupwara, and Poonch border sectors.\n" +
        "• Isolated off-beat mountain trails late in the afternoon or during adverse weather.\n" +
        "• Avoid traveling by road on highways at late night hours without local clearance.\n\n" +
        "✅ Recommended Safe Tourist Circuits:\n" +
        "• Srinagar (Dal Lake, Boulevard Road, Shankaracharya Temple), Gulmarg, Pahalgam, and Sonamarg are well-patrolled and tourist-friendly.\n\n" +
        "💡 Safety Advice:\n" +
        "• Always carry government photo ID.\n" +
        "• Hire registered J&K Tourism guides with valid identity badges.\n" +
        "• Emergency Tourist Police helpline: 112 / 0194-2450012.";
    }
    return "Jammu & Kashmir is famous for its breathtaking landscapes! Here are the safe travel guidelines:\n\n" +
      "• Safe Circuits: Srinagar (Dal Lake, Mughal Gardens), Gulmarg (Gondola ride), and Pahalgam are very popular and secured.\n" +
      "• Travel Tip: Use verified prepaid taxis or licensed tour operators from the Tourist Reception Centre (TRC).\n" +
      "• Weather Alert: Check weather advisories before heading to mountain passes in winter or monsoon.\n" +
      "• Stay within designated tourist zones and avoid border proximity zones.";
  }

  // 3. Specific Region: Delhi / NCR
  if (lower.includes('delhi') || lower.includes('ncr') || lower.includes('gurgaon') || lower.includes('noida')) {
    return "Safety Guidelines for Delhi & NCR:\n\n" +
      "• Safe Zones: Central Delhi (Connaught Place, India Gate), South Delhi (Hauz Khas, Saket), and Aerocity.\n" +
      "• Caution Areas: Avoid poorly lit alleys and walking alone late at night around isolated railway exits or secluded outer ring roads.\n" +
      "• Transport: The Delhi Metro is highly secure and has dedicated women's coaches. For cabs, use official app-based services (Uber/Ola) with trip sharing enabled.\n" +
      "• Emergency Helpline: Dial 112 (Police: 1091 for women's safety).";
  }

  // 4. Specific Region: Goa / Beaches
  if (lower.includes('goa') || lower.includes('beach') || lower.includes('swimming')) {
    return "Beach & Coastal Safety Tips:\n\n" +
      "• Water Safety: Always obey beach flags. Never enter the water when Red Flags are raised or after sunset.\n" +
      "• Lifeguards: Swim only in zones monitored by certified Drishti Marine lifeguards.\n" +
      "• Night Safety: Stick to well-lit, active beach stretches like Baga, Calangute, or Palolem. Avoid secluded rocks at night.\n" +
      "• Transport: Rent scooters only from authorized vendors and always wear an ISI-certified helmet.";
  }

  // 5. Questions about "where not to visit" / "places to avoid" / "danger zones"
  if (lower.includes('avoid') || lower.includes('not visit') || lower.includes('danger') || lower.includes('unsafe') || lower.includes('risk')) {
    return "General Safety Rules on Places to Avoid while Traveling:\n\n" +
      "1. Unmarked Border & Restricted Zones: Never venture near national defense borders without military permits.\n" +
      "2. Deserted Night Areas: Avoid unlit alleys, empty parks, and unmonitored bus/train terminals after dark.\n" +
      "3. Red Danger Geofences: Check the 'Map' tab on your app — our system alerts you when you approach designated high-risk zones.\n" +
      "4. Unlicensed Tour Operators: Avoid touts at airports/stations offering unofficial private tours.\n\n" +
      "If you enter an area that feels unsafe, tap the red SOS Emergency button on the Home screen immediately!";
  }

  // 6. Tourist Guide / Recommendations / Places to visit
  if (lower.includes('guide') || lower.includes('visit') || lower.includes('place') || lower.includes('tourist') || lower.includes('recommend') || lower.includes('sightseeing')) {
    return "SafeTour AI Travel Guide Recommendations:\n\n" +
      "• Map Safe Zones: Look at the 'Map' tab in SafeTour AI. Green zones indicate verified safe tourist areas with active surveillance.\n" +
      "• Digital ID: Store your verifiable identity credentials in the 'Digital ID' tab so you never lose physical travel documents.\n" +
      "• Local Verification: Always choose government-accredited hotels, registered taxis, and licensed guides.\n" +
      "• Need details on a specific city? Type the city or state name (e.g., 'Is Kashmir safe?', 'Tips for Delhi') and I'll give you customized advice!";
  }

  // 7. Night Safety / Walking late
  if (lower.includes('night') || lower.includes('dark') || lower.includes('walk') || lower.includes('evening') || lower.includes('alone')) {
    return "Night Travel & Walking Safety Tips:\n\n" +
      "• Stick to main, well-lit avenues with active commercial establishments.\n" +
      "• Avoid using earbuds or staring into your phone while walking alone at night.\n" +
      "• Keep your SafeTour AI location tracking active so your emergency geofences remain active.\n" +
      "• Always book cabs via verified apps and share your live ride status with friends or family.";
  }

  // 8. Emergency / Police / Hospital / SOS
  if (lower.includes('emergency') || lower.includes('police') || lower.includes('hospital') || lower.includes('help') || lower.includes('sos') || lower.includes('doctor')) {
    return "🚨 Emergency Safety Protocol:\n\n" +
      "• National Emergency (India): Dial **112** (Police: 100, Ambulance: 102, Tourist Helpline: 1363).\n" +
      "• In-App SOS: Press the red **SOS EMERGENCY** button on your Home screen to instantly send your GPS coordinates to responders.\n" +
      "• Find Help Nearby: Tap the **Nearby** button in Quick Access to locate the closest hospitals, pharmacies, and police stations on the map.";
  }

  // 9. Scams / Fraud / Overcharging
  if (lower.includes('scam') || lower.includes('cheat') || lower.includes('money') || lower.includes('taxi') || lower.includes('expensive')) {
    return "Common Tourist Scam Alerts & How to Avoid Them:\n\n" +
      "• Fake Ticket Counters: Always buy monument and transport tickets directly from official government websites or verified counters.\n" +
      "• Broken Taxi Meter Excuse: Insist on metered fares or agree on official pre-paid booth rates before boarding.\n" +
      "• Friendly Stranger Touts: Be wary of unsolicited strangers claiming your hotel is closed and directing you elsewhere.\n" +
      "• Keep emergency numbers saved and report scams to the Tourist Police.";
  }

  // 10. Check if completely unrelated (e.g. coding, math, non-travel)
  const isTravelRelated = /(travel|tour|safe|visit|city|place|hotel|flight|trip|map|train|bus|car|country|food|water|guide|alert|location|stay)/i.test(lower);
  if (!isTravelRelated && lower.length > 20 && !/(kashmir|delhi|mumbai|goa|india|usa|paris|london|bangalore|hyderabad|chennai)/i.test(lower)) {
    return "I am SafeTour AI, your dedicated travel and tourist safety assistant! I specialize in:\n• Recommending safe places to visit and dangerous zones to avoid\n• Local travel precautions and scam alerts\n• Emergency helpline guidance and safety navigation\n\nPlease ask me any travel or location safety question!";
  }

  // Default helpful tourist response
  return "As your SafeTour travel assistant, I recommend staying aware of your surroundings, sticking to well-patrolled tourist corridors, and keeping emergency numbers accessible.\n\nTip: You can ask me specific questions like:\n• 'Which places in Jammu & Kashmir should I avoid?'\n• 'How to avoid tourist scams?'\n• 'What are the emergency numbers here?'";
}

/**
 * Main Process Message Entrypoint
 */
exports.processMessage = async (userId, message) => {
  // First attempt: Gemini AI if key is configured
  const geminiReply = await callGemini(message);
  if (geminiReply) {
    return geminiReply;
  }

  // Fallback: SafeTour Tourist Safety Knowledge Engine
  // Simulate natural typing delay (400 - 800ms)
  await new Promise(resolve => setTimeout(resolve, 500 + Math.random() * 300));
  return getKnowledgeResponse(message);
};
