import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  OneToMany,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { MatchPlayer } from './match-player.entity';
import { Set } from './set.entity';
import { Territory } from '../../territories/entities/territory.entity';
import { User } from '../../users/entities/user.entity';

@Entity('matches')
export class Match {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'enum', enum: ['301', '501', '701', 'cricket', 'chasseur'] })
  mode: string;

  @Column({ type: 'enum', enum: ['double_out', 'single_out', 'master_out'], default: 'double_out' })
  finish: string;

  @Column({
    type: 'enum',
    enum: ['pending', 'in_progress', 'paused', 'completed', 'cancelled', 'awaiting_validation'],
    default: 'pending',
  })
  status: string;

  @Column({ type: 'int', default: 1 })
  total_sets: number;

  @Column({ type: 'int', default: 3 })
  legs_per_set: number;

  @Column({ type: 'uuid', nullable: true })
  inviter_id: string | null;

  @Column({ type: 'uuid', nullable: true })
  invitee_id: string | null;

  @Column({
    type: 'enum',
    enum: ['pending', 'accepted', 'refused'],
    nullable: true,
  })
  invitation_status: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  invitation_created_at: Date | null;

  @Column({ type: 'varchar', length: 9, nullable: true })
  territory_id: string | null;

  @Column({ type: 'uuid', nullable: true })
  territory_club_id: string | null;

  @Column({ type: 'varchar', length: 9, nullable: true })
  territory_code_iris: string | null;

  @Column({ type: 'boolean', default: false })
  is_territorial: boolean;

  @Column({ type: 'uuid', nullable: true })
  tournament_id: string | null;

  @Column({ type: 'boolean', default: false })
  is_offline: boolean;

  @Column({ type: 'boolean', default: false })
  is_ranked: boolean;

  @Column({ type: 'uuid', nullable: true })
  surrendered_by: string | null;

  @Column({ type: 'boolean', default: false })
  validated_by_home: boolean;

  @Column({ type: 'boolean', default: false })
  validated_by_away: boolean;

  @Column({ type: 'timestamptz', nullable: true })
  started_at: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  ended_at: Date | null;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @OneToMany(() => MatchPlayer, (mp) => mp.match)
  players: MatchPlayer[];

  @OneToMany(() => Set, (s) => s.match)
  sets: Set[];

  @ManyToOne(() => Territory, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'territory_id' })
  territory: Territory;

  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'surrendered_by' })
  surrendered_by_user: User;
}
