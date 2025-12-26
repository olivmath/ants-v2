// SVG rendering utilities

/**
 * Fetches SVG template from IPFS and renders it with ant colors
 */
export async function renderAntSVG(
  svgUri: string,
  antColor: string,
  eggColor: string
): Promise<string> {
  try {
    // Fetch SVG template from IPFS
    const response = await fetch(svgUri);
    if (!response.ok) {
      throw new Error(`Failed to fetch SVG: ${response.statusText}`);
    }

    let svgTemplate = await response.text();

    // Replace color placeholders with actual colors
    svgTemplate = svgTemplate.replace(/\{\{ANT_COLOR\}\}/g, antColor);
    svgTemplate = svgTemplate.replace(/\{\{EGG_COLOR\}\}/g, eggColor);

    return svgTemplate;
  } catch (error) {
    console.error('Error rendering ant SVG:', error);
    // Return a fallback SVG
    return createFallbackSVG(antColor, eggColor);
  }
}

/**
 * Creates a simple fallback SVG if IPFS fetch fails
 */
function createFallbackSVG(antColor: string, eggColor: string): string {
  return `
    <svg version="1.1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 260">
      <ellipse cx="100" cy="140" rx="80" ry="100" fill="${eggColor}" stroke="${antColor}" stroke-width="4"/>
      <circle cx="100" cy="120" r="30" fill="${antColor}"/>
      <text x="100" y="135" font-size="30" text-anchor="middle">🐜</text>
    </svg>
  `;
}

/**
 * Creates a data URL from SVG string
 */
export function svgToDataUrl(svg: string): string {
  const base64 = btoa(svg);
  return `data:image/svg+xml;base64,${base64}`;
}

/**
 * Gets the display color for an ant based on its state
 * Matches the contract logic
 */
export function getDisplayAntColor(ant: {
  isAlive: boolean;
  totalEggsLaid: number;
  color: string;
}): string {
  if (!ant.isAlive) {
    return '#FF0000'; // Red for dead ants
  } else if (ant.totalEggsLaid === 0) {
    return '#00FF00'; // Green for ants that haven't laid eggs yet
  } else {
    return ant.color; // Original color
  }
}
