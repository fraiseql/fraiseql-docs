# FraiseQL Website

The official documentation website for FraiseQL.

## Schema. Compile. Serve.

Define in your language. Configure in TOML. Compile to Rust. Serve at database speed.

## Development

```bash
# Install dependencies
bun install

# Start development server
bun run dev

# Build for production
bun run build

# Preview production build
bun run preview
```

## Stack

- **Framework:** Astro 5.x + Starlight
- **Styling:** Tailwind CSS 4.x
- **Fonts:** Inter + JetBrains Mono
- **Deployment:** Static (any CDN)

## Structure

```
src/
├── assets/           # Images, logos
├── components/       # Custom Astro components
├── content/docs/     # Documentation pages (Markdown/MDX)
│   ├── getting-started/
│   ├── concepts/
│   ├── guides/
│   ├── sdk/
│   ├── databases/
│   ├── vs/           # Comparison pages
│   └── reference/
├── pages/            # Custom pages
└── styles/           # Global CSS, design tokens
```

## Commands

| Command           | Action                                |
| :---------------- | :------------------------------------ |
| `bun install`     | Install dependencies                  |
| `bun run dev`     | Start dev server at `localhost:4321`  |
| `bun run build`   | Build production site to `./dist/`    |
| `bun run preview` | Preview production build              |
| `bun run check`   | Type check the project                |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `bun run build` to verify
5. Submit a pull request

## License

Apache 2.0
