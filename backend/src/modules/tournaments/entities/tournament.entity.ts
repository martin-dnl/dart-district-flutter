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

  @Column({ type: 'numeric', precision: 8, scale: 2, default: 0 })
  entry_fee: number;

  @Column({ type: 'int', default: 16 })
  max_clubs: number;

  @Column({ type: 'int', default: 0 })
  enrolled_clubs: number;

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
}
