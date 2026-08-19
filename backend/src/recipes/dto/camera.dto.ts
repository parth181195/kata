import {
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class ReportCameraDto {
  @IsString() @MaxLength(60) model!: string;
  @IsOptional() @IsString() @MaxLength(30) firmware?: string;
  @IsOptional() @IsInt() @Min(0) @Max(65535) pid?: number;
  @IsInt() @Min(1) @Max(7) slots!: number;
  @IsOptional() @IsInt() @Min(0) @Max(200) props?: number;
}
