import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Territory } from '../../territories/entities/territory.entity';
import { User } from '../../users/entities/user.entity';
import { Club } from '../../clubs/entities/club.entity';
import { Match } from '../../matches/entities/match.entity';

@Entity('duels')
export class Duel {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 9 })
  territory_id: string;

  @Column({ type: 'uuid' })
  challenger_id: string;

  @Column({ type: 'uuid', nullable: true })
  defender_id: string | null;

  @Column({ type: 'uuid' })
  challenger_club: string;

  @Column({ type: 'uuid', nullable: true })
  defender_club: string | null;

  @Column({ type: 'uuid', nullable: true })
  match_id: string | null;

  @Column({ type: 'uuid', nullable: true })
  qr_code_id: string | null;

  @Column({ type: 'enum', enum: ['pending', 'accepted', 'declined', 'expired', 'completed'], default: 'pending' })
  status: string;

  @Column({ type: 'timestamptz' })
  expires_at: Date;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @ManyToOne(() => Territory, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'territory_id' })
  territory: Territory;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'challenger_id' })
  challenger: User;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'defender_id' })
  defender: User;

  @ManyToOne(() => Club)
  @JoinColumn({ name: 'challenger_club', referencedColumnName: 'id' })
  challengerClub: Club;

  @ManyToOne(() => Club, { nullable: true })
  @JoinColumn({ name: 'defender_club', referencedColumnName: 'id' })
  defenderClub: Club;

  @ManyToOne(() => Match, { nullable: true })
  @JoinColumn({ name: 'match_id' })
  match: Match;
}
