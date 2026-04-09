import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('languages')
export class Language {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 10, unique: true })
  code: string;

  @Column({ type: 'varchar', length: 100 })
  country_name: string;

  @Column({ type: 'varchar', length: 100 })
  language_name: string;

  @Column({ type: 'varchar', length: 10 })
  flag_emoji: string;

  @Column({ type: 'boolean', default: false })
  is_available: boolean;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;
}
