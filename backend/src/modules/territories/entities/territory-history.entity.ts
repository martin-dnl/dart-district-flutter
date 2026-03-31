import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Territory } from './territory.entity';
import { Club } from '../../clubs/entities/club.entity';

@Entity('territory_history')
export class TerritoryHistory {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 9 })
  territory_id: string;

  @Column({ type: 'uuid', nullable: true })
  from_club_id: string | null;

  @Column({ type: 'uuid', nullable: true })
  to_club_id: string | null;

  @Column({ type: 'uuid', nullable: true })
  match_id: string | null;

  @Column({ type: 'varchar', length: 50 })
  event: string;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @ManyToOne(() => Territory, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'territory_id' })
  territory: Territory;

  @ManyToOne(() => Club, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'from_club_id' })
  from_club: Club;

  @ManyToOne(() => Club, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'to_club_id' })
  to_club: Club;
}
