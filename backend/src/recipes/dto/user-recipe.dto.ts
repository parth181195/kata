import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsObject,
  IsOptional,
  IsUrl,
  Min,
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

export class RevertDto {
  @IsInt() @Min(1) version!: number;
}
