/**
 * Is a page served from this computer? The tool is for the person editing a world on their own
 * machine, never for a site's visitors, so it starts nowhere else, whatever a build leaves in by mistake.
 */
export function isThisComputer(hostname: string): boolean {
  const host = hostname.toLowerCase();
  return host === "localhost" || host === "[::1]" || host === "::1" || /^127\.\d+\.\d+\.\d+$/.test(host) || host.endsWith(".localhost");
}
