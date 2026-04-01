import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Tournament } from './tournament.entity';
import { User } from '../../users/entities/user.entity';

@Entity('tournament_bracket_matches')
export class TournamentBracketMatch {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid')
  tournament_id: string;

  @Column('int')
  round_number: number;

  @Column('int')
  position: number;

  @Column({ type: 'uuid', nullable: true })
  player1_id: string | null;

  @Column({ type: 'uuid', nullable: true })
  player2_id: string | null;

  @Column({ type: 'uuid', nullable: true })
  winner_id: string | null;

  @Column({ type: 'uuid', nullable: true })
  match_id: string | null;

  @Column({ type: 'varchar', length: 20, default: 'pending' })
  status: string;

  @Column({ type: 'timestamptz', nullable: true })
  scheduled_at: Date | null;

  @ManyToOne(() => Tournament, (tournament) => tournament.bracket_matches, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'tournament_id' })
  tournament: Tournament;

  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'player1_id' })
  player1: User | null;

  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'player2_id' })
  player2: User | null;

  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'winner_id' })
  winner: User | null;
}
