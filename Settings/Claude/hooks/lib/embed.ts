const LM_STUDIO_URL = 'http://127.0.0.1:1234/v1/embeddings';
const MODEL = 'text-embedding-nomic-embed-text-v1.5';
const HEALTH_CHECK_URL = 'http://127.0.0.1:1234/v1/models';

export async function checkLMStudio(): Promise<boolean> {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 3000);

    const res = await fetch(HEALTH_CHECK_URL, { signal: controller.signal });
    clearTimeout(timeout);

    return res.ok;
  } catch {
    return false;
  }
}

export async function getEmbedding(text: string): Promise<number[]> {
  const res = await fetch(LM_STUDIO_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: MODEL, input: text })
  });

  if (!res.ok) {
    throw new Error(`LM Studio embedding failed: ${res.status}`);
  }

  const data = await res.json() as { data: Array<{ embedding: number[] }> };
  return data.data[0].embedding;
}
