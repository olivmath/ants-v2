import { useState, useEffect } from 'react';
import { renderAntSVG, getDisplayAntColor, svgToDataUrl } from '@/lib/svg';

interface AntImageProps {
  antColor: string;
  eggColor: string;
  isAlive: boolean;
  totalEggsLaid: number;
  svgUri: string | null;
  alt?: string;
  className?: string;
}

export function AntImage({
  antColor,
  eggColor,
  isAlive,
  totalEggsLaid,
  svgUri,
  alt = 'Ant NFT',
  className = '',
}: AntImageProps) {
  const [imageSrc, setImageSrc] = useState<string>('');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadSVG = async () => {
      if (!svgUri) {
        setError('No SVG URI provided');
        setIsLoading(false);
        return;
      }

      try {
        setIsLoading(true);
        setError(null);

        // Get the display color based on ant state
        const displayAntColor = getDisplayAntColor({
          isAlive,
          totalEggsLaid,
          color: antColor,
        });

        // Render SVG with colors
        const svg = await renderAntSVG(svgUri, displayAntColor, eggColor);
        const dataUrl = svgToDataUrl(svg);

        setImageSrc(dataUrl);
      } catch (err) {
        console.error('Failed to load ant SVG:', err);
        setError('Failed to load image');
      } finally {
        setIsLoading(false);
      }
    };

    loadSVG();
  }, [antColor, eggColor, isAlive, totalEggsLaid, svgUri]);

  if (isLoading) {
    return (
      <div className={`ant-image-placeholder ${className}`}>
        <span style={{ fontSize: '3rem' }}>🐜</span>
        <p style={{ fontSize: '0.8rem', marginTop: '0.5rem' }}>Loading...</p>
      </div>
    );
  }

  if (error || !imageSrc) {
    return (
      <div className={`ant-image-placeholder ${className}`}>
        <span style={{ fontSize: '3rem' }}>🐜</span>
        <p style={{ fontSize: '0.8rem', marginTop: '0.5rem', color: '#999' }}>
          {error || 'No image'}
        </p>
      </div>
    );
  }

  return <img src={imageSrc} alt={alt} className={className} />;
}
