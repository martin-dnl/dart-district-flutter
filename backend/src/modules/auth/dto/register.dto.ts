import {
  IsEmail,
  IsString,
  MinLength,
  IsOptional,
  IsEnum,
  ValidateIf,
} from 'class-validator';

export enum RegisterProvider {
  LOCAL = 'local',
  GOOGLE = 'google',
  APPLE = 'apple',
  GUEST = 'guest',
}

export class RegisterDto {
  @IsString()
  @MinLength(2)
  display_name: string;

  @ValidateIf((o: RegisterDto) =>
    (o.provider ?? RegisterProvider.LOCAL) !== RegisterProvider.GUEST,
  )
  @IsEmail()
  email?: string;

  @ValidateIf(
    (o: RegisterDto) =>
      (o.provider ?? RegisterProvider.LOCAL) === RegisterProvider.LOCAL,
  )
  @IsString()
  @MinLength(8)
  password?: string;

  @IsEnum(RegisterProvider)
  @IsOptional()
  provider?: RegisterProvider = RegisterProvider.LOCAL;

  @IsString()
  @IsOptional()
  provider_uid?: string;

  @IsString()
  @IsOptional()
  avatar_url?: string;
}
