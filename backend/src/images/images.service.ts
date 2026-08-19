import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { PrismaService } from '../prisma/prisma.service';
import { BunnyClient } from './bunny.client';

const ALLOWED = new Set(['image/jpeg', 'image/png', 'image/webp']);

@Injectable()
export class ImagesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly bunny: BunnyClient,
  ) {}

  async uploadRecipeImage(
    recipeId: string,
    file: { buffer: Buffer; mimetype: string },
  ): Promise<{ url: string; thumbUrl: string }> {
    if (!ALLOWED.has(file.mimetype))
      throw new BadRequestException('Only JPEG, PNG or WebP');
    const recipe = await this.prisma.recipe.findUnique({
      where: { id: recipeId },
    });
    if (!recipe) throw new NotFoundException();
    let main: Buffer, thumb: Buffer;
    try {
      const base = sharp(file.buffer).rotate();
      main = await base
        .clone()
        .resize({
          width: 1600,
          height: 1600,
          fit: 'inside',
          withoutEnlargement: true,
        })
        .jpeg({ quality: 82 })
        .toBuffer();
      thumb = await base
        .clone()
        .resize({
          width: 400,
          height: 400,
          fit: 'inside',
          withoutEnlargement: true,
        })
        .jpeg({ quality: 80 })
        .toBuffer();
    } catch {
      throw new BadRequestException('Could not decode image');
    }
    const id = randomUUID();
    const url = await this.bunny.put(
      `recipes/${recipeId}/${id}.jpg`,
      main,
      'image/jpeg',
    );
    const thumbUrl = await this.bunny.put(
      `recipes/${recipeId}/${id}_t.jpg`,
      thumb,
      'image/jpeg',
    );
    await this.prisma.recipe.update({
      where: { id: recipeId },
      data: { imageUrls: { push: url } },
    });
    return { url, thumbUrl };
  }
}
