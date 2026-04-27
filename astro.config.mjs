// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import fs from 'node:fs';

import sitemap from '@astrojs/sitemap';

const praiaGrammar = JSON.parse(
    fs.readFileSync(new URL('./src/praia.tmLanguage.json', import.meta.url), 'utf-8')
);

export default defineConfig({
    site: 'https://praia.sh',
    markdown: {
        shikiConfig: {
            langs: [{
                ...praiaGrammar,
                id: 'praia',
                aliases: ['praia'],
            }],
        },
    },
    integrations: [starlight({
        title: 'Praia',
        description: 'A dynamically typed programming language with pipes, generators, and async built in.',
        social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/praia-lang/praia' }],
        favicon: '/favicon.png',
        logo: {
            src: './src/assets/logo.png',
            replacesTitle: false,
        },
        sidebar: [
            {
                label: 'Getting Started',
                items: [
                    { label: 'Installation', slug: 'getting-started/installation' },
                    { label: 'Hello World', slug: 'getting-started/hello-world' },
                    { label: 'REPL', slug: 'getting-started/repl' },
                ],
            },
            {
                label: 'Language',
                autogenerate: { directory: 'language' },
            },
            {
                label: 'Standard Library',
                autogenerate: { directory: 'stdlib' },
            },
            {
                label: 'Grains & Sand',
                items: [
                    { label: 'Module System', slug: 'grains/modules' },
                    { label: 'Standard Grains', slug: 'grains/standard' },
                    { label: 'Sand Package Manager', slug: 'grains/sand' },
                ],
            },
            {
                label: 'Advanced',
                autogenerate: { directory: 'advanced' },
            },
        ],
        customCss: ['./src/styles/custom.css'],
        expressiveCode: {
            shiki: {
                langs: [{
                    ...praiaGrammar,
                    id: 'praia',
                    aliases: ['praia'],
                }],
            },
        },
		}), sitemap()],
});