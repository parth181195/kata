import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
} from 'class-validator';

export class PatchRecipeDto {
  @IsOptional() @IsBoolean() reviewed?: boolean;
  @IsOptional() @IsBoolean() hidden?: boolean;
  @IsOptional() @IsString() @MaxLength(60) name?: string;
  @IsOptional() @IsString() @MaxLength(120) sourceAttribution?: string;
  @IsOptional()
  @IsUrl({ require_protocol: true })
  @MaxLength(400)
  sourceUrl?: string;
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(8)
  @IsString({ each: true })
  sensors?: string[];
  @IsOptional()
  @IsArray()
  // seeded katas carry a post's full set of sample frames, not a token few
  @ArrayMaxSize(24)
  @IsUrl({ require_protocol: true }, { each: true })
  imageUrls?: string[];
}
