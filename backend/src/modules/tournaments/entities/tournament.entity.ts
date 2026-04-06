import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
} from 'typeorm';
import { Territory } from '../../territories/entities/territory.entity';
import { User } from '../../users/entities/user.entity';
import { Club } from '../../clubs/entities/club.entity';
import { TournamentPlayer } from './tournament-player.entity';
import { TournamentPool } from './tournament-pool.entity';
import { TournamentBracketMatch } from './tournament-bracket-match.entity';

@Entity('tournaments')
export class Tournament {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 150 })
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ type: 'varchar', length: 9, nullable: true })
  territory_id: string | null;

  @Column({ type: 'boolean', default: false })
  is_territorial: boolean;

  @Column({ type: 'boolean', default: false })
  is_ranked: boolean;

  @Column({ type: 'enum', enum: ['301', '501', '701', 'cricket', 'chasseur'], default: '501' })
  mode: string;

  @Column({ type: 'enum', enum: ['double_out', 'single_out', 'master_out'], default: 'double_out' })
  finish: string;

  @Column({ type: 'varchar', length: 200, nullable: true })
  venue_name: string | null;

  @Column({ type: 'text', nullable: true })
  venue_address: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  city: string | null;

  @Column({ type: 'uuid', nullable: true })
  club_id: string | null;

  @Column({ type: 'numeric', precision: 8, scale: 2, default: 0 })
  entry_fee: number;

  @Column({ type: 'int', default: 16 })
  max_players: number;

  @Column({ type: 'int', default: 0 })
  enrolled_players: number;

  @Column({ type: 'varchar', length: 20, default: 'single_elimination' })
  format: string;

  @Column({ type: 'int', nullable: true })
  pool_count: number | null;

  @Column({ type: 'int', nullable: true })
  players_per_pool: number | null;

  @Column({ type: 'int', default: 2 })
  qualified_per_pool: number;

  @Column({ type: 'int', default: 3 })
  legs_per_set_pool: number;

  @Column({ type: 'int', default: 1 })
  sets_to_win_pool: number;

  @Column({ type: 'int', default: 5 })
  legs_per_set_bracket: number;

  @Column({ type: 'int', default: 1 })
  sets_to_win_bracket: number;

  @Column({ type: 'varchar', length: 20, default: 'registration' })
  current_phase: string;

  @Column({ type: 'varchar', length: 30, default: 'open' })
  status: string;

  @Column({ type: 'timestamptz' })
  scheduled_at: Date;

  @Column({ type: 'timestamptz', nullable: true })
  ended_at: Date | null;

  @Column({ type: 'uuid', nullable: true })
  created_by: string | null;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @ManyToOne(() => Territory, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'territory_id' })
  territory: Territory;

  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'created_by' })
  creator: User;

  @ManyToOne(() => Club, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'club_id' })
  club: Club;

  @OneToMany(() => TournamentPlayer, (player) => player.tournament)
  players: TournamentPlayer[];

  @OneToMany(() => TournamentPool, (pool) => pool.tournament)
  pools: TournamentPool[];

  @OneToMany(() => TournamentBracketMatch, (match) => match.tournament)
  bracket_matches: TournamentBracketMatch[];
}
