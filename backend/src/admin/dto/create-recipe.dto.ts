import {
  IsArray,
  IsBoolean,
  IsObject,
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateRecipeDto {
  @IsObject() ofr!: Record<string, unknown>;
  @IsOptional() @IsArray() @IsString({ each: true }) imageUrls?: string[];
  @IsOptional() @IsBoolean() reviewed?: boolean;
  @IsOptional() @IsBoolean() hidden?: boolean;
}
