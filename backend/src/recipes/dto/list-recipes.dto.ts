import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const toBool = ({ value }: { value: unknown }) =>
  value === 'true' || value === true
    ? true
    : value === 'false' || value === false
      ? false
      : value;

export class ListRecipesDto {
  @IsOptional() @IsString() @MaxLength(80) q?: string;
  @IsOptional() @IsString() @MaxLength(40) sensor?: string;
  @IsOptional() @IsString() @MaxLength(40) filmSim?: string;
  @IsOptional() @Transform(toBool) @IsBoolean() mono?: boolean;
  @IsOptional() @Transform(toBool) @IsBoolean() verified?: boolean;
  @IsOptional() @IsIn(['newest', 'popular']) sort: 'newest' | 'popular' =
    'newest';
  @IsOptional() @IsString() @MaxLength(200) cursor?: string;
  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(50)
  limit = 30;
}
