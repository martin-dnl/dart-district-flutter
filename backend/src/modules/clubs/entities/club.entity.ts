import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { ClubMember } from './club-member.entity';

@Entity('clubs')
export class Club {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 100, unique: true })
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ type: 'text', nullable: true })
  avatar_url: string | null;

  @Column({ type: 'text', nullable: true })
  address: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  city: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  region: string | null;

  @Column({ type: 'varchar', length: 10, nullable: true })
  postal_code: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true, default: 'France' })
  country: string | null;

  @Column({ type: 'jsonb', nullable: true })
  opening_hours: Record<string, { open: string; close: string }> | null;

  @Column({ type: 'numeric', precision: 10, scale: 7, nullable: true })
  latitude: number | null;

  @Column({ type: 'numeric', precision: 10, scale: 7, nullable: true })
  longitude: number | null;

  @Column({ type: 'varchar', length: 9, nullable: true })
  code_iris: string | null;

  @Column({ type: 'int', default: 0 })
  conquest_points: number;

  @Column({ type: 'smallint', default: 0 })
  dart_boards_count: number;

  @Column({ type: 'int', nullable: true })
  rank: number | null;

  @Column({ type: 'varchar', length: 20, default: 'active' })
  status: string;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;

  @OneToMany(() => ClubMember, (cm) => cm.club)
  members: ClubMember[];
}
