#!/usr/bin/env node

/**
 * Add accessible titles to SVG diagrams for WCAG 2.1 compliance
 * Usage: node scripts/add-svg-titles.js
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const diagramDir = path.join(__dirname, '../public/diagrams');

const titles = {
  'compilation-01-parsing.svg': 'Compilation Phase 1: Parsing schema files into a type graph',
  'compilation-01-parsing-dark.svg': 'Compilation Phase 1 (Dark): Parsing schema files into a type graph',
  'compilation-02-analysis.svg': 'Compilation Phase 2: Type analysis and SQL generation',
  'compilation-02-analysis-dark.svg': 'Compilation Phase 2 (Dark): Type analysis and SQL generation',
  'compilation-03-codegen.svg': 'Compilation Phase 3: Rust code generation and output artifacts',
  'compilation-03-codegen-dark.svg': 'Compilation Phase 3 (Dark): Rust code generation and output artifacts',
  'cqrs-problem.svg': 'CQRS Problem: Single table serving competing read and write concerns',
  'cqrs-problem-dark.svg': 'CQRS Problem (Dark): Single table serving competing read and write concerns',
  'cqrs-solution.svg': 'CQRS Solution: Write tables and read views separated with auto-sync',
  'cqrs-solution-dark.svg': 'CQRS Solution (Dark): Write tables and read views separated with auto-sync',
  'cqrs-separation.svg': 'CQRS Separation: Architectural pattern separating read and write operations',
  'cqrs-separation-dark.svg': 'CQRS Separation (Dark): Architectural pattern separating read and write operations',
  'mutation-flow.svg': 'Mutation Flow: Step-by-step data mutation and view sync process',
  'mutation-flow-dark.svg': 'Mutation Flow (Dark): Step-by-step data mutation and view sync process',
  'observer-01-flow.svg': 'Observer Flow: Trigger to condition evaluation to async action execution',
  'observer-01-flow-dark.svg': 'Observer Flow (Dark): Trigger to condition evaluation to async action execution',
  'observer-02-actions.svg': 'Observer Actions: Webhook, Email, Slack, and Custom action types',
  'observer-02-actions-dark.svg': 'Observer Actions (Dark): Webhook, Email, Slack, and Custom action types',
  'three-stages.svg': 'Three-Stage Process: Define schema, compile, and serve GraphQL API',
  'three-stages-dark.svg': 'Three-Stage Process (Dark): Define schema, compile, and serve GraphQL API',
};

let processedCount = 0;

Object.entries(titles).forEach(([filename, title]) => {
  const filepath = path.join(diagramDir, filename);

  if (!fs.existsSync(filepath)) {
    console.warn(`Warning: File not found: ${filepath}`);
    return;
  }

  try {
    let content = fs.readFileSync(filepath, 'utf-8');

    // Check if title already exists
    if (content.includes('<title>' + title + '</title>')) {
      console.log(`✓ ${filename} (title already present)`);
      processedCount++;
      return;
    }

    // Find the first nested <svg class="d2-xxx d2-svg" tag and add title and ARIA attributes
    const match = content.match(
      /(<svg class="d2-[^"]*\s+d2-svg"[^>]*)(>)/
    );

    if (match) {
      // Add ARIA and role attributes to the SVG tag
      const svgId = filename.replace(/\.svg$/, '').replace(/-/g, '_');
      const svgWithAttrs = match[1] + ' role="img" aria-labelledby="' + svgId + '"' + match[2];
      content = content.replace(
        match[0],
        svgWithAttrs + `<title id="${svgId}">${title}</title>`
      );

      fs.writeFileSync(filepath, content);
      console.log(`✓ ${filename}`);
      processedCount++;
    } else {
      console.warn(`Warning: Could not find SVG opener in ${filename}`);
    }
  } catch (error) {
    console.error(`Error processing ${filename}:`, error.message);
  }
});

console.log(`\n✓ Added titles to ${processedCount}/${Object.keys(titles).length} diagrams`);
