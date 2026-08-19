import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsIn,
  IsUUID,
} from 'class-validator';

export const BULK_ACTIONS = ['approve', 'verify', 'hide', 'unhide'] as const;
export type BulkAction = (typeof BULK_ACTIONS)[number];

export class BulkDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(100)
  @IsUUID('4', { each: true })
  ids!: string[];
  @IsIn(BULK_ACTIONS) action!: BulkAction;
}
