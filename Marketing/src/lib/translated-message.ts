let messages: Record<string, string> | undefined;
/** Saved, build-time translations. No browser translation or network request. */
export function translatedMessage(source: string): string {
  if (!messages) {
    const data = document.querySelector<HTMLElement>('[data-translated-messages]')?.dataset.translatedMessages;
    messages = data ? JSON.parse(data) : {};
  }
  return messages?.[source.replace(/\s+/g, ' ').trim()] ?? source;
}
