import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  OneToOne,
} from 'typeorm';
import { AuthProvider } from '../../auth/entities/auth-provider.entity';
import { PlayerStat } from '../../stats/entities/player-stat.entity';
import { ClubMember } from '../../clubs/entities/club-member.entity';
import { UserBadge } from '../../badges/entities/user-badge.entity';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 60, unique: true })
  username: string;

  @Column({ type: 'varchar', length: 255, unique: true, nullable: true })
  email: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true, select: false })
  password_hash: string | null;

  @Column({ type: 'text', nullable: true })
  avatar_url: string | null;

  @Column({ type: 'int', default: 1000 })
  elo: number;

  @Column({ type: 'boolean', default: false })
  is_guest: boolean;

  @Column({ type: 'boolean', default: true })
  is_active: boolean;

  @Column({ type: 'boolean', default: false })
  has_tournament_abandon: boolean;

  @Column({ type: 'boolean', default: false })
  is_admin: boolean;

  @Column({ type: 'varchar', length: 10, default: 'right' })
  preferred_hand: string;

  @Column({ type: 'varchar', length: 20, default: 'intermediate' })
  level: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  city: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  region: string | null;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;

  @OneToMany(() => AuthProvider, (ap) => ap.user)
  auth_providers: AuthProvider[];

  @OneToOne(() => PlayerStat, (ps) => ps.user)
  stats: PlayerStat;

  @OneToMany(() => ClubMember, (cm) => cm.user)
  club_memberships: ClubMember[];

  @OneToMany(() => UserBadge, (ub) => ub.user)
  user_badges: UserBadge[];
}
