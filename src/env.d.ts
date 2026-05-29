/// <reference path="../.astro/types.d.ts" />
/// <reference types="astro/client" />

// Starlight virtual modules. `@astrojs/starlight/virtual` exports the
// public surface; `@astrojs/starlight/virtual-internal` declares the
// internal virtuals (including `virtual:starlight/user-images` consumed
// by `src/components/SiteTitle.astro`).
//
// The package doesn't expose these as named subpath exports, so we
// reference the .d.ts files directly through the resolved node_modules
// path. Astro's `astro check` walks this reference; the path is portable
// across check-outs because every install lands the package at the same
// relative location.
/// <reference path="../node_modules/@astrojs/starlight/virtual.d.ts" />
/// <reference path="../node_modules/@astrojs/starlight/virtual-internal.d.ts" />

