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
    updated: z.coerce.date().optional(),
    intro: z.string().optional(),
    takeaways: z.array(z.string()).max(4).default([]),
    contents: z.boolean().default(true),
    author: z.object({ name: z.string(), url: z.url() })
      .default({ name: 'Teleprompter Pal team', url: 'https://teleprompterpal.com/' }),
    topics: z.array(z.string()).default([]),
    relatedGuides: z.array(z.string()).max(3).default([]),
    relatedResources: z.array(z.object({ title: z.string(), description: z.string(), href: z.string().startsWith('/') })).max(3).default([]),
    shareImage: z.object({ src: z.string().startsWith('/images/'), alt: z.string(), width: z.number().int().positive(), height: z.number().int().positive() }).optional(),
    coverImage: z.object({
      src: z.string().startsWith('/images/'), alt: z.string(),
      width: z.number().int().positive(), height: z.number().int().positive(), caption: z.string().optional(),
      mobileSrc: z.string().startsWith('/images/').optional(),
      sources: z.array(z.object({ src: z.string().startsWith('/images/'), width: z.number().int().positive() })).default([]),
    }).optional(),
    thumbnail: z.object({ src: z.string().startsWith('/images/'), width: z.number().int().positive(), height: z.number().int().positive() }).optional(),
    draft: z.boolean().default(true),
  }),
});

export const collections = { guides };
