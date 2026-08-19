import { IsBoolean, IsIn } from 'class-validator';

export class PatchUserDto {
  @IsIn(['user', 'admin']) role!: 'user' | 'admin';
}

export class PatchReportDto {
  @IsBoolean() resolved!: boolean;
}
