"use client";

import { formatDayKey } from "@/lib/date-utils";
import type { MoodPoint } from "@/lib/summary-utils";

const MOOD_MIN = 0;
const MOOD_MAX = 10;
const CHART_HEIGHT = 120;
const CHART_PADDING = { top: 8, right: 8, bottom: 24, left: 28 };

type MoodTrendChartProps = {
  points: MoodPoint[];
  className?: string;
};

function scaleY(value: number, innerHeight: number): number {
  const range = MOOD_MAX - MOOD_MIN;
  const normalized = range > 0 ? (value - MOOD_MIN) / range : 0;
  return CHART_PADDING.top + innerHeight * (1 - normalized);
}

export function MoodTrendChart({ points, className = "" }: MoodTrendChartProps) {
  const width = 400;
  const innerWidth = width - CHART_PADDING.left - CHART_PADDING.right;
  const innerHeight = CHART_HEIGHT - CHART_PADDING.top - CHART_PADDING.bottom;

  const hasData = points.some((p) => p.count > 0);
  if (!hasData) {
    return (
      <p className={`text-sm text-text-secondary ${className}`}>
        No mood data for this period yet.
      </p>
    );
  }

  const stepX = points.length > 1 ? innerWidth / (points.length - 1) : 0;

  const linePoints = points
    .map((point, index) => {
      const x = CHART_PADDING.left + index * stepX;
      const y =
        point.count > 0
          ? scaleY(point.average, innerHeight)
          : scaleY(MOOD_MIN, innerHeight);
      return `${x},${y}`;
    })
    .join(" ");

  const barWidth = Math.max(4, Math.min(16, innerWidth / Math.max(points.length, 1) - 2));

  return (
    <svg
      viewBox={`0 0 ${width} ${CHART_HEIGHT}`}
      className={`w-full max-w-full ${className}`}
      role="img"
      aria-label="Mood trend chart"
    >
      {[0, 5, 10].map((tick) => {
        const y = scaleY(tick, innerHeight);
        return (
          <g key={tick}>
            <line
              x1={CHART_PADDING.left}
              y1={y}
              x2={width - CHART_PADDING.right}
              y2={y}
              stroke="var(--color-border-subtle)"
              strokeWidth={1}
            />
            <text
              x={CHART_PADDING.left - 6}
              y={y + 4}
              textAnchor="end"
              fill="var(--color-text-muted)"
              fontSize={10}
            >
              {tick}
            </text>
          </g>
        );
      })}

      {points.map((point, index) => {
        if (point.count === 0) return null;
        const x = CHART_PADDING.left + index * stepX - barWidth / 2;
        const barHeight =
          scaleY(point.average, innerHeight) - scaleY(MOOD_MIN, innerHeight);
        const y = scaleY(point.average, innerHeight);
        return (
          <rect
            key={point.date}
            x={x}
            y={y}
            width={barWidth}
            height={Math.max(2, barHeight)}
            rx={2}
            fill="var(--color-primary)"
            opacity={0.35}
          />
        );
      })}

      <polyline
        fill="none"
        stroke="var(--color-primary)"
        strokeWidth={2}
        strokeLinejoin="round"
        strokeLinecap="round"
        points={linePoints}
      />

      {points.map((point, index) => {
        if (point.count === 0) return null;
        const x = CHART_PADDING.left + index * stepX;
        const y = scaleY(point.average, innerHeight);
        return (
          <circle
            key={`dot-${point.date}`}
            cx={x}
            cy={y}
            r={3}
            fill="var(--color-primary)"
          />
        );
      })}

      {points.length <= 14 &&
        points.map((point, index) => {
          if (index % Math.ceil(points.length / 7) !== 0 && index !== points.length - 1) {
            return null;
          }
          const x = CHART_PADDING.left + index * stepX;
          return (
            <text
              key={`label-${point.date}`}
              x={x}
              y={CHART_HEIGHT - 4}
              textAnchor="middle"
              fill="var(--color-text-muted)"
              fontSize={9}
            >
              {formatDayKey(point.date).replace(/,\s*\d{4}$/, "")}
            </text>
          );
        })}
    </svg>
  );
}
