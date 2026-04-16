// Lerke — generate-glose edge function
// Accepts a text + language settings + teacher's own LLM API key.
// Proxies to Anthropic (Claude Haiku) or OpenAI (GPT-4o-mini).
// The teacher supplies their own key — Lerke is never billed.

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

interface GenerateRequest {
  text: string
  from_lang: string
  to_lang: string
  word_count: number
  provider: 'anthropic' | 'openai'
  api_key: string
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers: corsHeaders })
  }

  let body: GenerateRequest
  try {
    body = await req.json()
  } catch {
    return json({ error: 'Ugyldig JSON-body' }, 400)
  }

  const { text, from_lang, to_lang, word_count, provider, api_key } = body

  if (!text?.trim()) return json({ error: 'Tekst mangler' }, 400)
  if (!api_key?.trim()) return json({ error: 'API-nøkkel mangler' }, 400)
  if (!['anthropic', 'openai'].includes(provider)) return json({ error: 'Ukjent leverandør' }, 400)

  const count = Math.min(Math.max(parseInt(String(word_count)) || 10, 3), 30)
  const prompt = buildPrompt(text.slice(0, 4000), from_lang, to_lang, count)

  try {
    let pairs: [string, string][]
    if (provider === 'anthropic') {
      pairs = await callClaude(prompt, api_key.trim())
    } else {
      pairs = await callOpenAI(prompt, api_key.trim())
    }
    return json({ pairs })
  } catch (err) {
    return json({ error: (err as Error).message || 'LLM-feil' }, 502)
  }
})

function buildPrompt(text: string, from: string, to: string, count: number): string {
  return `Du er en lærer som lager glosebingo for elever. Trekk ut nøyaktig ${count} nyttige vokabularord fra teksten nedenfor (på ${from}) og oversett dem til ${to}. Velg ord som er pedagogisk nyttige – ikke velg svært vanlige ord som "the", "a", "er", "og". Returner KUN et JSON-array med par på denne formen: [["${from}-ord", "${to}-oversettelse"], ...]. Ikke inkluder noen forklaring eller annen tekst.

Tekst:
${text}`
}

async function callClaude(prompt: string, key: string): Promise<[string, string][]> {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': key,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 1024,
      messages: [{ role: 'user', content: prompt }],
    }),
  })

  if (!res.ok) {
    const err = await res.json().catch(() => ({}))
    throw new Error(err?.error?.message || `Anthropic API ${res.status}`)
  }

  const data = await res.json()
  const text = data?.content?.[0]?.text ?? ''
  return parsePairs(text)
}

async function callOpenAI(prompt: string, key: string): Promise<[string, string][]> {
  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 1024,
    }),
  })

  if (!res.ok) {
    const err = await res.json().catch(() => ({}))
    throw new Error(err?.error?.message || `OpenAI API ${res.status}`)
  }

  const data = await res.json()
  const text = data?.choices?.[0]?.message?.content ?? ''
  return parsePairs(text)
}

function parsePairs(text: string): [string, string][] {
  const match = text.match(/\[[\s\S]*\]/)
  if (!match) throw new Error('Klarte ikke å tolke svar fra AI — prøv igjen')
  try {
    const parsed = JSON.parse(match[0])
    if (!Array.isArray(parsed)) throw new Error('Ugyldig format')
    return parsed
      .filter((p) => Array.isArray(p) && p.length >= 2)
      .map((p) => [String(p[0]).trim(), String(p[1]).trim()])
      .filter(([a, b]) => a && b)
  } catch {
    throw new Error('Klarte ikke å tolke JSON fra AI')
  }
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
