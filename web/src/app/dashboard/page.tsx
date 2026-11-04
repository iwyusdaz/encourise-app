"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

interface Student {
  device_uuid: string;
  name: string;
  grade: number;
  last_sync: string;
  accuracy?: number;
  sessions_count?: number;
}

export default function DashboardPage() {
  const [students, setStudents] = useState<Student[]>([]);
  const [guidedCount, setGuidedCount] = useState(0);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchStudents();
  }, []);

  async function fetchStudents() {
    const { data: studentsData } = await supabase
      .from("students_cloud")
      .select("*")
      .order("last_sync", { ascending: false });

    // Fetch guided session count
    const { count: guidedTotal } = await supabase
      .from("sessions_cloud")
      .select("*", { count: "exact", head: true })
      .eq("mode", "guided");
    setGuidedCount(guidedTotal ?? 0);

    if (studentsData) {
      // Enrich with session data
      const enriched = await Promise.all(
        studentsData.map(async (s) => {
          const { data: sessions } = await supabase
            .from("sessions_cloud")
            .select("accuracy")
            .eq("device_uuid", s.device_uuid);

          const accuracies = sessions?.map((sess) => sess.accuracy) ?? [];
          const avgAccuracy =
            accuracies.length > 0
              ? accuracies.reduce((a, b) => a + b, 0) / accuracies.length
              : 0;

          return {
            ...s,
            accuracy: avgAccuracy,
            sessions_count: sessions?.length ?? 0,
          };
        })
      );
      setStudents(enriched);
    }
    setLoading(false);
  }

  function getStatusBadge(lastSync: string) {
    const days = Math.floor(
      (Date.now() - new Date(lastSync).getTime()) / (1000 * 60 * 60 * 24)
    );
    if (days <= 7)
      return <Badge className="bg-accent text-accent-foreground">Aktif</Badge>;
    if (days <= 14)
      return <Badge className="bg-[#EFD3C5] text-foreground">Tidak Aktif</Badge>;
    return <Badge className="bg-destructive text-foreground">Lama Tidak Aktif</Badge>;
  }

  // Stats
  const totalStudents = students.length;
  const activeStudents = students.filter((s) => {
    const days = Math.floor(
      (Date.now() - new Date(s.last_sync).getTime()) / (1000 * 60 * 60 * 24)
    );
    return days <= 7;
  }).length;
  const avgAccuracy =
    students.length > 0
      ? students.reduce((sum, s) => sum + (s.accuracy ?? 0), 0) / students.length
      : 0;

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border px-6 py-4 flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-foreground">Encourise</h1>
          <p className="text-sm text-muted-foreground">Teacher Dashboard</p>
        </div>
        <nav className="flex gap-4 text-sm">
          <Link href="/dashboard" className="font-medium text-primary">
            Kelas
          </Link>
          <Link href="/dashboard/heatmap" className="text-muted-foreground hover:text-primary">
            Heatmap
          </Link>
        </nav>
      </header>

      <main className="max-w-6xl mx-auto px-6 py-8">
        {/* Stat cards */}
        <div className="grid grid-cols-1 sm:grid-cols-4 gap-4 mb-8">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                Total Siswa
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold">{totalStudents}</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                Aktif Minggu Ini
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-primary">{activeStudents}</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                Rata-rata Akurasi
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold">{(avgAccuracy * 100).toFixed(0)}%</p>
              <Progress value={avgAccuracy * 100} className="mt-2 h-2" />
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                Jalur Belajar
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-green-600">{guidedCount}</p>
              <p className="text-xs text-muted-foreground mt-1">sesi guided total</p>
            </CardContent>
          </Card>
        </div>

        {/* Student table */}
        <Card>
          <CardHeader>
            <CardTitle>Daftar Siswa</CardTitle>
          </CardHeader>
          <CardContent>
            {loading ? (
              <p className="text-muted-foreground text-center py-8">Memuat data…</p>
            ) : students.length === 0 ? (
              <p className="text-muted-foreground text-center py-8">
                Belum ada data siswa. Data akan muncul setelah siswa melakukan sinkronisasi.
              </p>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Nama</TableHead>
                    <TableHead>Kelas</TableHead>
                    <TableHead>Sesi</TableHead>
                    <TableHead>Akurasi</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Terakhir Sync</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {students.map((student) => (
                    <TableRow key={student.device_uuid}>
                      <TableCell>
                        <Link
                          href={`/dashboard/student/${student.device_uuid}`}
                          className="font-medium text-primary hover:underline"
                        >
                          {student.name}
                        </Link>
                      </TableCell>
                      <TableCell>{student.grade}</TableCell>
                      <TableCell>{student.sessions_count}</TableCell>
                      <TableCell>
                        {((student.accuracy ?? 0) * 100).toFixed(0)}%
                      </TableCell>
                      <TableCell>{getStatusBadge(student.last_sync)}</TableCell>
                      <TableCell className="text-muted-foreground text-sm">
                        {new Date(student.last_sync).toLocaleDateString("id-ID")}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>
      </main>
    </div>
  );
}
