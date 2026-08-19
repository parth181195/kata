import { Transform } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export const QUEUE_TABS = [
  'pending',
  'reported',
  'published',
  'hidden',
  'all',
] as const;
export type QueueTab = (typeof QUEUE_TABS)[number];

export class CursorDto {
  @IsOptional() @IsString() @MaxLength(80) q?: string;
  @IsOptional() @IsString() @MaxLength(200) cursor?: string;
  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(50)
  limit = 30;
}

export class QueueDto extends CursorDto {
  @IsOptional() @IsIn(QUEUE_TABS) tab: QueueTab = 'pending';
  @IsOptional() @IsString() @MaxLength(40) sensor?: string;
  @IsOptional() @IsString() @MaxLength(40) filmSim?: string;
}

export class ReportsQueryDto extends CursorDto {
  @IsOptional() @IsIn(['open', 'resolved', 'all']) status:
    'open' | 'resolved' | 'all' = 'open';
}
