import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Tournament } from './tournament.entity';
import { User } from '../../users/entities/user.entity';
import { TournamentPool } from './tournament-pool.entity';

@Entity('tournament_players')
export class TournamentPlayer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid')
  tournament_id: string;

  @Column('uuid')
  user_id: string;

  @Column({ type: 'int', nullable: true })
  seed: number | null;

  @Column({ type: 'uuid', nullable: true })
  pool_id: string | null;

  @Column({ type: 'boolean', default: false })
  is_qualified: boolean;

  @Column({ type: 'boolean', default: false })
  is_disqualified: boolean;

  @Column({ type: 'text', nullable: true })
  disqualification_reason: string | null;

  @CreateDateColumn({ type: 'timestamptz' })
  registered_at: Date;

  @ManyToOne(() => Tournament, (tournament) => tournament.players, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'tournament_id' })
  tournament: Tournament;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @ManyToOne(() => TournamentPool, (pool) => pool.players, {
    onDelete: 'SET NULL',
  })
  @JoinColumn({ name: 'pool_id' })
  pool: TournamentPool | null;
}
