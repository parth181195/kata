import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { AdminService } from '../admin/admin.service';
import { AuthUser, CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ReportDto } from './dto/report.dto';

/** User-side moderation entry point (Stage 3): POST /recipes/:id/report */
@Controller('recipes')
@UseGuards(JwtAuthGuard)
export class ReportsController {
  constructor(private readonly admin: AdminService) {}

  @Post(':id/report')
  report(
    @Param('id') id: string,
    @Body() dto: ReportDto,
    @CurrentUser() u: AuthUser,
  ) {
    return this.admin.fileReport(id, u.id, dto.reason);
  }
}
