import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { env } from '../config/env';
import { UsersModule } from '../users/users.module';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { GoogleAuthLibraryVerifier } from './google-auth-library.verifier';
import { GoogleVerifier } from './google-verifier';
import { JwtAuthGuard } from './jwt-auth.guard';
import { RolesGuard } from './roles.guard';

@Module({
  imports: [
    JwtModule.register({ global: true, secret: env.jwtSecret }),
    UsersModule,
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    { provide: GoogleVerifier, useClass: GoogleAuthLibraryVerifier },
    JwtAuthGuard,
    RolesGuard,
  ],
  exports: [JwtModule, JwtAuthGuard, RolesGuard],
})
export class AuthModule {}
