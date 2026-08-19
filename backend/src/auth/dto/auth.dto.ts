import { IsString, MinLength } from 'class-validator';

export class GoogleSignInDto {
  @IsString()
  @MinLength(10)
  idToken!: string;
}

export class RefreshDto {
  @IsString()
  @MinLength(10)
  refreshToken!: string;
}
