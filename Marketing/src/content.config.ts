import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const guides = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/guides' }),
  schema: z.object({
    title: z.string(),
    headline: z.string(),
    breadcrumb: z.string().optional(),
    description: z.string(),
    date: z.coerce.date(),
    draft: z.boolean().default(true),
  }),
});

export const collections = { guides };
