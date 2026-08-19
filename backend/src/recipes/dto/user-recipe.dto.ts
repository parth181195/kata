import {
  ArrayMaxSize,
  IsArray,
  IsObject,
  IsOptional,
  IsUrl,
} from 'class-validator';

export class PublishRecipeDto {
  @IsObject() ofr!: Record<string, unknown>;
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(3)
  @IsUrl({ require_protocol: true }, { each: true })
  imageUrls?: string[];
}

export class UpdateRecipeDto {
  @IsObject() ofr!: Record<string, unknown>;
}
