import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

@Entity('app_version_policies')
@Index(['platform', 'is_active'])
export class AppVersionPolicy {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 16 })
  platform: 'android' | 'ios';

  @Column({ type: 'varchar', length: 32 })
  min_version: string;

  @Column({ type: 'varchar', length: 32 })
  recommended_version: string;

  @Column({ type: 'int', default: 1 })
  min_build: number;

  @Column({ type: 'int', default: 1 })
  recommended_build: number;

  @Column({ type: 'text', nullable: true })
  store_url_android: string | null;

  @Column({ type: 'text', nullable: true })
  store_url_ios: string | null;

  @Column({ type: 'text' })
  message_force_update: string;

  @Column({ type: 'text' })
  message_soft_update: string;

  @Column({ type: 'boolean', default: true })
  is_active: boolean;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;
}
